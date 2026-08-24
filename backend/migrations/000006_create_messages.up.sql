CREATE TABLE messages (
    id UUID NOT NULL,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    content TEXT,
    metadata JSONB,
    reply_to UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_messages_conversation_created ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);

-- Initial Partitions (2026-08 through 2027-01)
CREATE TABLE messages_y2026m08 PARTITION OF messages FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE messages_y2026m09 PARTITION OF messages FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE messages_y2026m10 PARTITION OF messages FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE messages_y2026m11 PARTITION OF messages FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE messages_y2026m12 PARTITION OF messages FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE messages_y2027m01 PARTITION OF messages FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');

CREATE TABLE message_reactions (
    message_id UUID NOT NULL,
    message_created_at TIMESTAMPTZ NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, message_created_at, user_id, emoji),
    FOREIGN KEY (message_id, message_created_at) REFERENCES messages(id, created_at) ON DELETE CASCADE
);

CREATE TABLE read_receipts (
    message_id UUID NOT NULL,
    message_created_at TIMESTAMPTZ NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, message_created_at, user_id),
    FOREIGN KEY (message_id, message_created_at) REFERENCES messages(id, created_at) ON DELETE CASCADE
);
