// Package upload provides a file storage abstraction.
// Currently saves files to local disk under ./uploads/.
// To switch to Cloudflare R2, replace the Save function body —
// the rest of the codebase only calls upload.Save() and uses the returned URL.
package upload

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
)

const uploadDir = "./uploads"

func init() {
	os.MkdirAll(uploadDir, 0755)
}

// Save stores an uploaded file and returns its public URL.
// Placeholder: writes to ./uploads/<uuid>.<ext>
// R2 swap: replace this function body with S3-compatible PutObject call.
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
	allowed := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".pdf": true}
	if !allowed[ext] {
		return "", fmt.Errorf("file type %s not allowed", ext)
	}

	dir := filepath.Join(uploadDir, folder)
	os.MkdirAll(dir, 0755)

	filename := fmt.Sprintf("%s-%d%s", uuid.New().String()[:8], time.Now().Unix(), ext)
	dst := filepath.Join(dir, filename)

	out, err := os.Create(dst)
	if err != nil {
		return "", fmt.Errorf("create file: %w", err)
	}
	defer out.Close()

	if _, err := io.Copy(out, src); err != nil {
		return "", fmt.Errorf("write file: %w", err)
	}

	// Return a relative URL served by the static file handler
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
