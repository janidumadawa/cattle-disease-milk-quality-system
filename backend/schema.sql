
CREATE TABLE IF NOT EXISTS milk_samples (
    sample_id TEXT PRIMARY KEY,
    received_at TIMESTAMPTZ NOT NULL,
    measurement_duration_seconds INTEGER NOT NULL
        CHECK (measurement_duration_seconds BETWEEN 1 AND 300),

    data_mode TEXT NOT NULL
        CHECK (data_mode IN ('MIXED', 'SIMULATED', 'REAL')),
    demo_scenario TEXT NOT NULL
        CHECK (demo_scenario IN ('PASS', 'FAIL')),

    temperature_c DOUBLE PRECISION NOT NULL,
    temperature_source TEXT NOT NULL,

    ph DOUBLE PRECISION NOT NULL
        CHECK (ph BETWEEN 0 AND 14),
    ph_source TEXT NOT NULL,

    conductivity_us_cm DOUBLE PRECISION NOT NULL
        CHECK (conductivity_us_cm >= 0),
    conductivity_source TEXT NOT NULL,

    turbidity_ntu DOUBLE PRECISION NOT NULL
        CHECK (turbidity_ntu >= 0),
    turbidity_source TEXT NOT NULL,

    classification_result TEXT NOT NULL,
    classification_status TEXT NOT NULL,
    research_validated BOOLEAN NOT NULL DEFAULT FALSE,

    response_payload JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_milk_samples_received_at
    ON milk_samples (received_at DESC);
