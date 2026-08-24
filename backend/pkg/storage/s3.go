package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/miigho/miigho/internal/config"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// S3Client manages interactions with MinIO/S3 compatible storage.
type S3Client struct {
	client     *minio.Client
	bucketName string
}

// NewS3Client creates a new MinIO client and returns S3Client.
func NewS3Client(cfg *config.Config) (*S3Client, error) {
	minioClient, err := minio.New(cfg.MinIO.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIO.AccessKey, cfg.MinIO.SecretKey, ""),
		Secure: cfg.MinIO.UseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to initialize minio client: %w", err)
	}

	return &S3Client{
		client:     minioClient,
		bucketName: cfg.MinIO.BucketName,
	}, nil
}

// EnsureBucket creates the default bucket if it doesn't exist.
func (s *S3Client) EnsureBucket(ctx context.Context) error {
	exists, err := s.client.BucketExists(ctx, s.bucketName)
	if err != nil {
		return fmt.Errorf("failed to check if bucket exists: %w", err)
	}
	if !exists {
		err = s.client.MakeBucket(ctx, s.bucketName, minio.MakeBucketOptions{})
		if err != nil {
			return fmt.Errorf("failed to create bucket: %w", err)
		}
	}
	return nil
}

// GeneratePresignedUploadURL generates a presigned URL for uploading an object.
func (s *S3Client) GeneratePresignedUploadURL(ctx context.Context, objectKey, contentType string, expiry time.Duration) (string, error) {
	url, err := s.client.PresignedPutObject(ctx, s.bucketName, objectKey, expiry)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned upload url: %w", err)
	}
	return url.String(), nil
}

// GeneratePresignedDownloadURL generates a presigned URL for downloading an object.
func (s *S3Client) GeneratePresignedDownloadURL(ctx context.Context, objectKey string, expiry time.Duration) (string, error) {
	url, err := s.client.PresignedGetObject(ctx, s.bucketName, objectKey, expiry, nil)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned download url: %w", err)
	}
	return url.String(), nil
}

// DeleteObject deletes an object from the bucket.
func (s *S3Client) DeleteObject(ctx context.Context, objectKey string) error {
	err := s.client.RemoveObject(ctx, s.bucketName, objectKey, minio.RemoveObjectOptions{})
	if err != nil {
		return fmt.Errorf("failed to delete object: %w", err)
	}
	return nil
}
