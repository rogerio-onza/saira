# Encoding Rules - Saira Project

1. All source files (`.R`, `.css`, `.js`, `.md`) must be UTF-8 without BOM.
2. R strings with non-ASCII characters must use `\uXXXX` escapes.
   - `Rog\u00E9rio` yes, raw accented literals no.
3. Comments should use ASCII only. Use `Rogerio`, not accented forms.
4. CSV output must use `readr::write_csv()` (UTF-8 without BOM by default).
5. CSV input must always handle optional BOM via `strip_bom()`.
6. Never use `options(encoding = "UTF-8")` in startup code.
7. Use LF line endings only (`.editorconfig` + `.gitattributes`).
8. I/O tests should write bytes explicitly when BOM behavior is under test.
9. `inst/extdata/i18n.json` uses literal UTF-8 (valid per JSON spec). The loader
   reads with `encoding = "UTF-8"` and applies `strip_bom()` for resilience.
   When editing the JSON manually, keep UTF-8 encoding and avoid raw BOM bytes.
10. Avoid `<<-` in package code. Use explicit environment management or
    structured return values instead:
    - In `tryCatch` handlers: `result <- tryCatch(expr, error = function(e) e)`
      followed by `if (inherits(result, "error")) { ... }`.
    - For mutable closure state: `env <- new.env(parent = emptyenv())` and
      access via `env$field`.
    - For multi-step helpers: pass state as explicit arguments and return a
      named list (`list(out_a = ..., out_b = ...)`) instead of mutating parent
      scope.
