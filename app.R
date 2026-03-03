# Title: Saira App Entry Point
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

# Load all package functions (dev mode only; skipped when installed)
if (requireNamespace("pkgload", quietly = TRUE) && !isNamespaceLoaded("saira")) {
    pkgload::load_all(export_all = FALSE, quiet = TRUE)
}

# Run the application
run_app()
