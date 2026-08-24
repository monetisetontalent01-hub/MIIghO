CREATE TABLE media_files (
    id UUID PRIMARY KEY,
    uploader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bucket_name VARCHAR(100) NOT NULL,
    object_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    processing_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, processed, failed
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_media_files_uploader_id ON media_files(uploader_id);
