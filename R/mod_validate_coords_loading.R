# Title: Validate Coordinates Module - Loading Modal Helpers
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-07
# Version: 1.0
# Pattern: follows mod_mapping_loading.R (Rostrum-style blocking modal)

#' Loading phrase specifications for the validate coords loading modal
#' @noRd
validate_coords_loading_phrase_specs <- function() {
    list(
        list(key = "loading_coords_phrase_1", icon = "map-location-dot"),
        list(key = "loading_coords_phrase_2", icon = "water"),
        list(key = "loading_coords_phrase_3", icon = "earth-americas"),
        list(key = "loading_coords_phrase_4", icon = "circle-check")
    )
}

#' Show the validate coords loading modal (Rostrum-style)
#'
#' Progress is purely client-side animated (0->92%) since validate_coords_cc_df()
#' is a single blocking batch call with no per-row progress callbacks.
#'
#' @param ns Module namespace function
#' @param lang_r Reactive or plain language string
#' @noRd
show_validate_coords_loading_modal <- function(ns, lang_r) {
    specs <- validate_coords_loading_phrase_specs()
    phrase_count <- length(specs)
    phrase_order <- sample(seq_len(phrase_count))
    ordered_specs <- specs[phrase_order]
    first_spec <- ordered_specs[[1]]

    status_template <- tr("validate_coords_loading_status", lang_r())
    status_prefix <- trimws(gsub("%s%%", "", status_template, fixed = TRUE))
    if (!nzchar(status_prefix)) {
        status_prefix <- tr("loading", lang_r())
    }

    rotate_script <- sprintf(
        "(function () {
                    var iconEl = document.getElementById('%s');
                    var textEl = document.getElementById('%s');
                    var rowEl = document.getElementById('%s');
                    var poolRoot = document.getElementById('%s');
                    var progressEl = document.getElementById('%s');
                    var statusEl = document.getElementById('%s');
                    if (!iconEl || !textEl || !rowEl || !poolRoot) { return; }

                    var items = poolRoot.querySelectorAll('.automap-loading-phrase-item');
                    if (!items.length) { return; }

                    var timerKey = '%s';
                    var timeoutKey = timerKey + '_fade';
                    var progressKey = timerKey + '_progress';
                    var fadeMs = 280;
                    var stepMs = 2500;
                    var modalEl = poolRoot.closest('.modal');
                    var statusPrefix = %s;
                    var progressValue = 0;

                    var applyProgress = function (value) {
                        var pct = Math.max(0, Math.min(100, Math.round(value)));
                        if (progressEl) {
                            progressEl.style.width = pct + '%%';
                        }
                        if (statusEl) {
                            statusEl.textContent = statusPrefix ? (statusPrefix + ' ' + pct + '%%') : (pct + '%%');
                        }
                    };

                    if (modalEl) {
                        modalEl.classList.add('automap-loading-host');
                    }
                    if (document.body) {
                        document.body.classList.add('automap-loading-open');
                    }

                    if (window[timerKey]) {
                        window.clearInterval(window[timerKey]);
                        window[timerKey] = null;
                    }
                    if (window[timeoutKey]) {
                        window.clearTimeout(window[timeoutKey]);
                        window[timeoutKey] = null;
                    }
                    if (window[progressKey]) {
                        window.clearInterval(window[progressKey]);
                        window[progressKey] = null;
                    }

                    var applyPhrase = function (index) {
                        var item = items[index];
                        if (!item) { return; }
                        var nextIcon = item.getAttribute('data-icon') || 'gears';
                        iconEl.className = 'fa-solid fa-' + nextIcon + ' automap-loading-phrase-icon';
                        textEl.textContent = item.textContent || '';
                    };

                    var idx = 0;
                    applyPhrase(idx);
                    applyProgress(progressValue);

                    window[timerKey] = window.setInterval(function () {
                        rowEl.classList.add('is-fading');
                        window[timeoutKey] = window.setTimeout(function () {
                            idx = (idx + 1) %% items.length;
                            applyPhrase(idx);
                            rowEl.classList.remove('is-fading');
                            window[timeoutKey] = null;
                        }, fadeMs);
                    }, stepMs);

                    window[progressKey] = window.setInterval(function () {
                        if (progressValue < 92) {
                            progressValue += 1;
                            applyProgress(progressValue);
                        }
                    }, 500);

                    var clearTimer = function () {
                        if (window[timerKey]) {
                            window.clearInterval(window[timerKey]);
                            window[timerKey] = null;
                        }
                        if (window[timeoutKey]) {
                            window.clearTimeout(window[timeoutKey]);
                            window[timeoutKey] = null;
                        }
                        if (window[progressKey]) {
                            window.clearInterval(window[progressKey]);
                            window[progressKey] = null;
                        }
                        if (modalEl) {
                            modalEl.classList.remove('automap-loading-host');
                        }
                        if (document.body) {
                            document.body.classList.remove('automap-loading-open');
                        }
                    };

                    if (modalEl) {
                        modalEl.addEventListener('hidden.bs.modal', clearTimer, { once: true });
                    } else {
                        document.addEventListener('hidden.bs.modal', clearTimer, { once: true });
                    }
                })();",
        ns("coords_loading_phrase_icon"),
        ns("coords_loading_phrase_text"),
        ns("coords_loading_phrase_row"),
        ns("coords_loading_phrase_pool"),
        ns("coords_loading_progress_bar"),
        ns("coords_loading_status_text"),
        ns("coords_loading_phrase_timer"),
        jsonlite::toJSON(status_prefix, auto_unbox = TRUE)
    )

    shiny::showModal(shiny::modalDialog(
        shiny::div(
            class = "automap-loading-modal",
            shiny::div(
                class = "automap-loading-brand-row",
                shiny::icon("earth-americas", class = "fa-solid automap-loading-brand-icon")
            ),
            shiny::div(
                class = "automap-loading-title",
                tr("validate_coords_loading_title", lang_r())
            ),
            shiny::div(
                class = "automap-loading-progress",
                shiny::div(
                    id = ns("coords_loading_progress_bar"),
                    class = "automap-loading-progress-bar",
                    style = "width: 0%;"
                )
            ),
            shiny::div(
                class = "automap-loading-status",
                shiny::span(
                    id = ns("coords_loading_status_text"),
                    sprintf(tr("validate_coords_loading_status", lang_r()), 0L)
                )
            ),
            shiny::div(
                class = "automap-loading-phrase",
                shiny::div(
                    class = "automap-loading-phrase-row",
                    id = ns("coords_loading_phrase_row"),
                    shiny::icon(
                        first_spec$icon,
                        id = ns("coords_loading_phrase_icon"),
                        class = "fa-solid automap-loading-phrase-icon"
                    ),
                    shiny::span(
                        tr(first_spec$key, lang_r()),
                        id = ns("coords_loading_phrase_text")
                    )
                ),
                shiny::div(
                    id = ns("coords_loading_phrase_pool"),
                    style = "display: none;",
                    lapply(ordered_specs, function(spec) {
                        shiny::span(
                            class = "automap-loading-phrase-item",
                            `data-icon` = spec$icon,
                            tr(spec$key, lang_r())
                        )
                    })
                ),
                shiny::tags$script(shiny::HTML(rotate_script))
            )
        ),
        easyClose = FALSE,
        footer = NULL,
        fade = TRUE
    ))
}

#' Hide the validate coords loading modal
#' @noRd
hide_validate_coords_loading_modal <- function() {
    shiny::removeModal()
}
