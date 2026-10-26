param(
    [string]$Rscript,
    [string]$OutputDirectory,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Rscript) {
    $Command = Get-Command Rscript.exe -ErrorAction SilentlyContinue
    if ($Command) { $Rscript = $Command.Source }
    else {
        $Candidates = Get-ChildItem "$env:ProgramFiles\R\R-*\bin\Rscript.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending
        if ($Candidates) { $Rscript = $Candidates[0].FullName }
    }
}
if (-not $Rscript -or -not (Test-Path $Rscript)) { throw 'Install R >= 4.5.0 on Windows or pass -Rscript.' }
if (Test-Path "$env:ProgramFiles\nodejs\node.exe") {
    $env:Path = "$env:ProgramFiles\nodejs;$env:Path"
}
$env:RENV_CONFIG_AUTOLOADER_ENABLED = 'FALSE'
Push-Location $Root
try {
    if (-not $CheckOnly) {
        & $Rscript --vanilla "$PSScriptRoot\bootstrap.R"
        if ($LASTEXITCODE -ne 0) { throw 'Desktop bootstrap failed.' }
    }
    $BuildArguments = @('--vanilla', "$PSScriptRoot\build.R")
    if ($CheckOnly) { $BuildArguments += '--check' }
    if ($OutputDirectory) { $BuildArguments += "--output=$OutputDirectory" }
    & $Rscript @BuildArguments
    if ($LASTEXITCODE -ne 0) { throw 'Desktop build failed.' }
}
finally { Pop-Location }
