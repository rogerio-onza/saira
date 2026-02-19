# Title: Finch App Entry Point
# Author: Rogério Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

options(encoding = "UTF-8")

# Load all package functions
pkgload::load_all(export_all = FALSE, quiet = TRUE)

# Run the application
run_app()
