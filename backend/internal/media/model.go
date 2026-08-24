package media

import (
	"time"

	"github.com/google/uuid"
)

type MediaFile struct {
	ID          uuid.UUID `json:"id"`
	UploaderID  uuid.UUID `json:"uploader_id"`
	Type        string    `json:"type"` // "image", "video", "audio", "document"
	ContentType string    `json:"content_type"`
	Size        int64     `json:"size"`
	Path        string    `json:"path"`
	URL         string    `json:"url"`
	Status      string    `json:"status"` // "pending", "uploaded", "processing", "ready"
	CreatedAt   time.Time `json:"created_at"`
}

type UploadRequest struct {
	ContentType string `json:"content_type" validate:"required"`
	FileSize    int64  `json:"file_size" validate:"required,gt=0"`
	Type        string `json:"type" validate:"required,oneof=image video audio document"`
}

type UploadCompleteRequest struct {
	MediaID uuid.UUID `json:"media_id" validate:"required"`
}
