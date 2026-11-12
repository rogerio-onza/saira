param([Parameter(Mandatory = $true)][string]$BuildDirectory)
$ErrorActionPreference = 'Stop'
$BuildDirectory = (Resolve-Path $BuildDirectory).Path
$Resources = Join-Path $BuildDirectory 'bundle\electron-app\dist\win-unpacked\resources\app.asar.unpacked'
$Runtime = Join-Path $Resources 'runtime\R'
$Library = Join-Path $Runtime 'library'
$Candidates = @(Get-ChildItem "$Runtime\*\bin\Rscript.exe")
if ($Candidates.Count -ne 1) { throw 'Expected one packaged Rscript.exe in win-unpacked.' }
$Rscript = $Candidates[0].FullName
& $Rscript --vanilla "$PSScriptRoot\smoke.R" "--library=$Library"
if ($LASTEXITCODE -ne 0) { throw 'Bundled R smoke test failed.' }

$Diagnostics = Join-Path $BuildDirectory 'diagnostics'
New-Item -ItemType Directory -Path $Diagnostics -Force | Out-Null
$Probe = Join-Path $Diagnostics 'http-probe.R'
@'
.libPaths(c(Sys.getenv("SAIRA_SMOKE_LIBRARY"), .Library), include.site = FALSE)
shiny::runApp(Sys.getenv("SAIRA_SMOKE_APP"), host = "127.0.0.1",
    port = as.integer(Sys.getenv("SAIRA_SMOKE_PORT")), launch.browser = FALSE)
'@ | Set-Content -LiteralPath $Probe -Encoding Ascii
$Listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$Listener.Start()
$Port = $Listener.LocalEndpoint.Port
$Listener.Stop()
$env:SAIRA_SMOKE_LIBRARY = $Library
$env:SAIRA_SMOKE_APP = Join-Path $Resources 'src\app'
$env:SAIRA_SMOKE_PORT = [string]$Port
$ErrorLog = Join-Path $Diagnostics 'http-stderr.log'
$Process = Start-Process -FilePath $Rscript -ArgumentList @('--vanilla', "`"$Probe`"") `
    -WorkingDirectory $Diagnostics -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $Diagnostics 'http-stdout.log') -RedirectStandardError $ErrorLog
try {
    $Response = $null
    for ($Attempt = 0; $Attempt -lt 100; $Attempt++) {
        if ($Process.HasExited) { throw "Shiny exited early. See $ErrorLog" }
        try {
            $Response = Invoke-WebRequest "http://127.0.0.1:$Port/" -UseBasicParsing -TimeoutSec 1
            break
        }
        catch { Start-Sleep -Milliseconds 250 }
    }
    if (-not $Response -or $Response.StatusCode -ne 200) { throw "Shiny did not respond. See $ErrorLog" }
    $Style = Invoke-WebRequest "http://127.0.0.1:$Port/www/custom.css" -UseBasicParsing -TimeoutSec 5
    if ($Style.StatusCode -ne 200 -or $Style.RawContentLength -lt 1000) { throw 'Packaged CSS was not served.' }
    Write-Output 'PASS: packaged Shiny launcher responds over localhost and serves its local CSS.'
}
finally {
    # Portable R's bin/Rscript.exe starts bin/x64/Rscript.exe on Windows.
    # Stop the complete test process tree so the child cannot retain the app cwd.
    if (-not $Process.HasExited) { & taskkill.exe /PID $Process.Id /T /F | Out-Null }
}
