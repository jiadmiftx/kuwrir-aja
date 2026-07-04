// Package upload provides a file storage abstraction. When Cloudflare R2
// credentials are configured (via Init), Save uploads to R2. Otherwise it
// falls back to local disk under ./uploads/ — the same safe-fallback shape
// as service.WhatsAppSender. Every caller only calls Save()/MustSave() and
// uses the returned URL, so this is the only file that needs to know which
// backend is active.
package upload

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/google/uuid"

	"github.com/kuwrir-platform/backend/internal/config"
)

const uploadDir = "./uploads"

var (
	r2Client    *s3.Client
	r2Bucket    string
	r2PublicURL string
)

func init() {
	os.MkdirAll(uploadDir, 0755)
}

// Init configures R2 as the upload backend. Called once at startup with
// cfg.R2; a no-op (local disk stays active) when AccountID is empty, so
// every environment without R2 credentials behaves exactly as before.
func Init(cfg config.R2Config) {
	if cfg.AccountID == "" {
		return
	}

	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", cfg.AccountID)
	r2Client = s3.New(s3.Options{
		Region:       "auto",
		BaseEndpoint: aws.String(endpoint),
		Credentials: credentials.NewStaticCredentialsProvider(
			cfg.AccessKeyID, cfg.AccessKeySecret, "",
		),
	})
	r2Bucket = cfg.BucketName
	r2PublicURL = strings.TrimSuffix(cfg.PublicURL, "/")
}

var contentTypes = map[string]string{
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".png":  "image/png",
	".webp": "image/webp",
	".pdf":  "application/pdf",
}

// Save stores an uploaded file and returns its public URL — from R2 when
// Init configured a client, otherwise ./uploads/<folder>/<uuid>.<ext> on
// local disk (served by the app's own static file handler).
func Save(fh *multipart.FileHeader, folder string) (string, error) {
	src, err := fh.Open()
	if err != nil {
		return "", fmt.Errorf("open upload: %w", err)
	}
	defer src.Close()

	ext := strings.ToLower(filepath.Ext(fh.Filename))
	if ext == "" {
		ext = ".bin"
	}

	// Reject obviously non-image extensions
	contentType, allowed := contentTypes[ext]
	if !allowed {
		return "", fmt.Errorf("file type %s not allowed", ext)
	}

	filename := fmt.Sprintf("%s-%d%s", uuid.New().String()[:8], time.Now().Unix(), ext)

	if r2Client != nil {
		return saveToR2(src, folder, filename, contentType)
	}
	return saveToDisk(src, folder, filename)
}

func saveToR2(src io.Reader, folder, filename, contentType string) (string, error) {
	data, err := io.ReadAll(src)
	if err != nil {
		return "", fmt.Errorf("read upload: %w", err)
	}

	key := folder + "/" + filename
	_, err = r2Client.PutObject(context.Background(), &s3.PutObjectInput{
		Bucket:      aws.String(r2Bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String(contentType),
	})
	if err != nil {
		return "", fmt.Errorf("r2 upload: %w", err)
	}

	return r2PublicURL + "/" + key, nil
}

func saveToDisk(src io.Reader, folder, filename string) (string, error) {
	dir := filepath.Join(uploadDir, folder)
	os.MkdirAll(dir, 0755)

	dst := filepath.Join(dir, filename)
	out, err := os.Create(dst)
	if err != nil {
		return "", fmt.Errorf("create file: %w", err)
	}
	defer out.Close()

	if _, err := io.Copy(out, src); err != nil {
		return "", fmt.Errorf("write file: %w", err)
	}

	return fmt.Sprintf("/uploads/%s/%s", folder, filename), nil
}

// MustSave saves a file or returns empty string on error (for optional fields).
func MustSave(fh *multipart.FileHeader, folder string) string {
	if fh == nil {
		return ""
	}
	url, _ := Save(fh, folder)
	return url
}
