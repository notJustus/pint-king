CREATE TABLE leaderboard_snapshots (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id    UUID        NOT NULL REFERENCES groups(id),
    user_id     UUID        NOT NULL REFERENCES users(id),
    period_type VARCHAR(10) NOT NULL CHECK (period_type IN ('week', 'month')),
    period_key  VARCHAR(10) NOT NULL,
    rank        INTEGER     NOT NULL,
    pint_count  INTEGER     NOT NULL,
    snapshot_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (group_id, user_id, period_type, period_key)
);

CREATE INDEX idx_snapshots_lookup ON leaderboard_snapshots (group_id, period_type, period_key);
