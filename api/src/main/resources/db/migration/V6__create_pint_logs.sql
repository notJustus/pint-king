CREATE TABLE pint_logs (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id),
    group_id   UUID        NOT NULL REFERENCES groups(id),
    photo_url  TEXT        NOT NULL,
    note       VARCHAR(280),
    drink_type VARCHAR(20) CHECK (drink_type IN ('beer', 'lager', 'ale', 'stout', 'cider')),
    location   GEOMETRY(Point, 4326),
    logged_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pint_logs_group_logged ON pint_logs (group_id, logged_at DESC);
CREATE INDEX idx_pint_logs_user_logged  ON pint_logs (user_id, logged_at DESC);
CREATE INDEX idx_pint_logs_location     ON pint_logs USING GIST (location);
