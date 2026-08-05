# Rostrum persists aliases and templates to tools::R_user_dir("saira", "data")
# unless SAIRA_DATA_DIR is set, so an unisolated suite writes into the
# developer's real rostrum.sqlite. It had accumulated 376 alias rows (two per
# run) plus their events before this was noticed. Setting it here covers every
# test file, which per-test withr::local_envvar calls never could.
#
# SAIRA_USER is deliberately NOT set: test-utils-rostrum-templates.R skips a
# test when it is set, because that test covers the unset case on purpose.
withr::local_envvar(
    c(SAIRA_DATA_DIR = withr::local_tempdir(.local_envir = teardown_env())),
    .local_envir = teardown_env()
)
