package service

import (
	"context"
	"encoding/base64"
	"log"
	"os"
	"sync"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/google/uuid"
	"google.golang.org/api/option"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

var (
	fcmClient *messaging.Client
	fcmOnce   sync.Once
)

// InitFCM initializes the Firebase Admin SDK from FIREBASE_SERVICE_ACCOUNT_JSON env var (base64-encoded JSON).
// Safe to call multiple times — only initializes once.
func InitFCM() {
	fcmOnce.Do(func() {
		raw := os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
		if raw == "" {
			log.Println("⚠️  FCM not initialized: FIREBASE_SERVICE_ACCOUNT_JSON is not set")
			return
		}

		var credBytes []byte
		decoded, err := base64.StdEncoding.DecodeString(raw)
		if err != nil {
			// Try raw JSON (not base64)
			credBytes = []byte(raw)
		} else {
			credBytes = decoded
		}

		opt := option.WithCredentialsJSON(credBytes)
		app, err := firebase.NewApp(context.Background(), nil, opt)
		if err != nil {
			log.Printf("⚠️  FCM not initialized: firebase.NewApp failed: %v", err)
			return
		}
		client, err := app.Messaging(context.Background())
		if err != nil {
			log.Printf("⚠️  FCM not initialized: app.Messaging failed: %v", err)
			return
		}
		fcmClient = client
		log.Println("✅ FCM (Firebase Admin SDK) initialized")
	})
}

// SendToUser sends a push notification to a user via their stored FCM token.
// Silently no-ops if the user has no token or FCM is not initialized.
func SendToUser(db *gorm.DB, userID uuid.UUID, title, body string, data map[string]string) {
	if fcmClient == nil {
		log.Printf("FCM send skipped for user %s: fcmClient not initialized", userID)
		return
	}

	var user model.User
	if err := db.Select("fcm_token").Where("id = ?", userID).First(&user).Error; err != nil {
		log.Printf("FCM send skipped for user %s: user lookup failed: %v", userID, err)
		return
	}
	if user.FCMToken == "" {
		log.Printf("FCM send skipped for user %s: no fcm_token on file", userID)
		return
	}

	msg := &messaging.Message{
		Token: user.FCMToken,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
		},
	}

	resp, err := fcmClient.Send(context.Background(), msg)
	if err != nil {
		log.Printf("FCM send failed for user %s: %v", userID, err)
		return
	}
	log.Printf("FCM sent to user %s: %s", userID, resp)
}
