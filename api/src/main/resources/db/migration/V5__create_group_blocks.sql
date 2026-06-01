CREATE TABLE group_blocks (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id   UUID        NOT NULL REFERENCES groups(id),
    user_id    UUID        NOT NULL REFERENCES users(id),
    blocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (group_id, user_id)
);

CREATE INDEX idx_group_blocks_lookup ON group_blocks (group_id, user_id);
