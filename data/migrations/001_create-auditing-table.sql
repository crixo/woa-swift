CREATE TABLE IF NOT EXISTS woa_auditing (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_table TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    recorded_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    change_type TEXT NOT NULL CHECK(change_type IN ('create', 'added', 'update', 'delete'))
);

CREATE INDEX IF NOT EXISTS idx_woa_auditing_recorded_at
    ON woa_auditing(recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_woa_auditing_entity
    ON woa_auditing(entity_table, entity_id);
