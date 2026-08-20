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

// SendToUser sends a push notification to a user via their stored FCM token,
// and always persists a Notification row first — regardless of whether FCM
// is initialized or the user has a live token — so a missed/dismissed push
// (or a stale token) doesn't mean the notification is gone for good; it's
// still readable later via GET /me/notifications.
func SendToUser(db *gorm.DB, userID uuid.UUID, title, body string, data map[string]string) {
	db.Create(&model.Notification{
		UserID: userID,
		Title:  title,
		Body:   body,
		Type:   data["type"],
	})

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
		Data:    data,
		Android: &messaging.AndroidConfig{Priority: "high"},
	}

	resp, err := fcmClient.Send(context.Background(), msg)
	if err != nil {
		log.Printf("FCM send failed for user %s: %v", userID, err)
		return
	}
	log.Printf("FCM sent to user %s: %s", userID, resp)
}

// SendAlarmToUser sends a data-only push (no `notification` block) — used
// for merchant_app's incoming-order alarm, where the client must build the
// notification itself (full-screen intent, custom channel, looping sound)
// rather than let Android auto-display a plain one. A message that carries
// a `notification` block gets shown directly by the OS whenever the app is
// backgrounded or killed, without ever running app code, so there's no way
// to attach a full-screen intent to it — that can only happen when the
// app's own background isolate builds the notification, which Android only
// guarantees for data-only messages. `title`/`body` travel inside `data` so
// the client has them to build the local notification from.
func SendAlarmToUser(db *gorm.DB, userID uuid.UUID, title, body string, data map[string]string) {
	if fcmClient == nil {
		log.Printf("FCM alarm send skipped for user %s: fcmClient not initialized", userID)
		return
	}

	var user model.User
	if err := db.Select("fcm_token").Where("id = ?", userID).First(&user).Error; err != nil {
		log.Printf("FCM alarm send skipped for user %s: user lookup failed: %v", userID, err)
		return
	}
	if user.FCMToken == "" {
		log.Printf("FCM alarm send skipped for user %s: no fcm_token on file", userID)
		return
	}

	alarmData := make(map[string]string, len(data)+2)
	for k, v := range data {
		alarmData[k] = v
	}
	alarmData["title"] = title
	alarmData["body"] = body

	msg := &messaging.Message{
		Token:   user.FCMToken,
		Data:    alarmData,
		Android: &messaging.AndroidConfig{Priority: "high"},
	}

	resp, err := fcmClient.Send(context.Background(), msg)
	if err != nil {
		log.Printf("FCM alarm send failed for user %s: %v", userID, err)
		return
	}
	log.Printf("FCM alarm sent to user %s: %s", userID, resp)
}
