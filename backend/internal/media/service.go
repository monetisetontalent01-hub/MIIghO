package media

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/pkg/storage"
)

type MediaService struct {
	s3 *storage.S3Client
}

func NewMediaService(s3 *storage.S3Client) *MediaService {
	return &MediaService{s3: s3}
}

func (s *MediaService) RequestUpload(ctx context.Context, userID uuid.UUID, req *UploadRequest) (map[string]interface{}, error) {
	mediaID := uuid.New()
	objectKey := fmt.Sprintf("%s/%s/%s", req.Type, userID.String(), mediaID.String())

	uploadURL, err := s.s3.GeneratePresignedUploadURL(ctx, objectKey, req.ContentType, 15*time.Minute)
	if err != nil {
		return nil, common.ErrInternal
	}

	return map[string]interface{}{
		"media_id":   mediaID,
		"upload_url": uploadURL,
		"object_key": objectKey,
	}, nil
}

func (s *MediaService) CompleteUpload(ctx context.Context, req *UploadCompleteRequest) (*MediaFile, error) {
	// Dummy logic, just returning a struct. Real implementation would check S3 and create DB record
	mf := &MediaFile{
		ID:        req.MediaID,
		Status:    "ready",
		CreatedAt: time.Now(),
	}
	return mf, nil
}

func (s *MediaService) GetMediaURL(ctx context.Context, mediaID uuid.UUID) (string, error) {
	// Dummy key logic
	objectKey := fmt.Sprintf("image/dummy/%s", mediaID.String())
	url, err := s.s3.GeneratePresignedDownloadURL(ctx, objectKey, 1*time.Hour)
	if err != nil {
		return "", err
	}
	return url, nil
}
