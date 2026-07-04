package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

// WhatsAppSender delivers an OTP code to a phone number over WhatsApp. The
// auth handler depends only on this interface, so swapping the underlying
// gateway (an unofficial Baileys-based service today, the official
// WhatsApp Business Cloud API later) never requires touching handler code.
type WhatsAppSender interface {
	SendOTP(phone, code string) error
}

// LogWhatsAppSender is the default implementation until a real WhatsApp
// gateway is wired up — it just logs the code server-side so the OTP
// endpoints are fully testable end-to-end today.
type LogWhatsAppSender struct{}

func (LogWhatsAppSender) SendOTP(phone, code string) error {
	log.Printf("[WhatsApp OTP - no gateway configured] %s -> %s", phone, code)
	return nil
}

// HTTPWhatsAppSender calls the self-hosted whatsapp-gateway service
// (whatsapp-gateway/, Baileys-based) over HTTP.
type HTTPWhatsAppSender struct {
	BaseURL string
	APIKey  string
	Client  *http.Client
}

func NewHTTPWhatsAppSender(baseURL, apiKey string) *HTTPWhatsAppSender {
	return &HTTPWhatsAppSender{
		BaseURL: baseURL,
		APIKey:  apiKey,
		Client:  &http.Client{Timeout: 15 * time.Second},
	}
}

func (s *HTTPWhatsAppSender) SendOTP(phone, code string) error {
	body, err := json.Marshal(map[string]string{"phone": phone, "code": code})
	if err != nil {
		return err
	}

	req, err := http.NewRequest(http.MethodPost, s.BaseURL+"/send-otp", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-API-Key", s.APIKey)

	resp, err := s.Client.Do(req)
	if err != nil {
		return fmt.Errorf("whatsapp gateway request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("whatsapp gateway returned status %d", resp.StatusCode)
	}
	return nil
}
