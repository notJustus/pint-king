CREATE TABLE users (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_id      VARCHAR(255) NOT NULL UNIQUE,
    display_name  VARCHAR(30)  NOT NULL,
    avatar_url    TEXT,
    active_group_id UUID,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
