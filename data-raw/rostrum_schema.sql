CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS rostrum_synonyms (
    term TEXT NOT NULL,
    synonym TEXT NOT NULL,
    language TEXT NOT NULL,
    context TEXT NOT NULL,
    confidence REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    validation_regex TEXT,
    notes TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    source TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY(term, synonym, language, context, source)
);

CREATE TABLE IF NOT EXISTS rostrum_aliases (
    alias_id INTEGER PRIMARY KEY,
    scope TEXT NOT NULL,
    user_id TEXT,
    institution_id TEXT,
    col_name_norm TEXT NOT NULL,
    dwc_term TEXT NOT NULL,
    confidence REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    reviewed INTEGER NOT NULL DEFAULT 0,
    deprecated INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    created_by TEXT,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS rostrum_alias_events (
    event_id INTEGER PRIMARY KEY,
    alias_id INTEGER,
    action TEXT NOT NULL,
    run_id TEXT,
    payload_json TEXT,
    created_at TEXT NOT NULL,
    created_by TEXT,
    FOREIGN KEY(alias_id) REFERENCES rostrum_aliases(alias_id)
);

CREATE TABLE IF NOT EXISTS rostrum_templates (
    template_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    scope TEXT NOT NULL,
    owner_id TEXT,
    institution_id TEXT,
    schema_version TEXT NOT NULL,
    app_min_version TEXT,
    app_max_version TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    description TEXT,
    use_case TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS rostrum_template_items (
    template_id TEXT NOT NULL,
    dwc_term TEXT NOT NULL,
    source_columns_json TEXT NOT NULL,
    transform_kind TEXT,
    transform_params_json TEXT,
    priority INTEGER NOT NULL DEFAULT 0,
    required INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(template_id, dwc_term),
    FOREIGN KEY(template_id) REFERENCES rostrum_templates(template_id)
);

CREATE TABLE IF NOT EXISTS rostrum_runs (
    run_id TEXT PRIMARY KEY,
    session_id TEXT,
    app_version TEXT,
    engine_version TEXT,
    rows_n INTEGER NOT NULL,
    cols_n INTEGER NOT NULL,
    elapsed_ms INTEGER NOT NULL,
    stage1_ms INTEGER,
    stage2_ms INTEGER,
    stage3_ms INTEGER,
    auto_n INTEGER NOT NULL DEFAULT 0,
    suggested_n INTEGER NOT NULL DEFAULT 0,
    ambiguous_n INTEGER NOT NULL DEFAULT 0,
    manual_n INTEGER NOT NULL DEFAULT 0,
    options_json TEXT,
    metrics_json TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS rostrum_run_details (
    run_id TEXT NOT NULL,
    term TEXT NOT NULL,
    column_name TEXT NOT NULL,
    name_score REAL,
    value_score REAL,
    penalty_score REAL,
    final_score REAL,
    veto_code TEXT,
    decision_band TEXT,
    explain_json TEXT,
    PRIMARY KEY(run_id, term, column_name),
    FOREIGN KEY(run_id) REFERENCES rostrum_runs(run_id)
);

CREATE INDEX IF NOT EXISTS idx_alias_lookup
ON rostrum_aliases (scope, user_id, institution_id, col_name_norm, dwc_term, deprecated);

CREATE INDEX IF NOT EXISTS idx_synonyms_term_lang
ON rostrum_synonyms (term, language, active);

CREATE INDEX IF NOT EXISTS idx_runs_created_at
ON rostrum_runs (created_at);

CREATE INDEX IF NOT EXISTS idx_alias_events_run_id
ON rostrum_alias_events (run_id);

CREATE INDEX IF NOT EXISTS idx_alias_events_created_at
ON rostrum_alias_events (created_at);

CREATE INDEX IF NOT EXISTS idx_synonyms_value
ON rostrum_synonyms (synonym);

CREATE INDEX IF NOT EXISTS idx_alias_active
ON rostrum_aliases (deprecated, reviewed);

CREATE INDEX IF NOT EXISTS idx_templates_catalog
ON rostrum_templates (institution_id, use_case, is_active, updated_at);
