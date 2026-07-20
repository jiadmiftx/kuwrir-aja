package service

import (
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/config"
	"github.com/kuwrir-platform/backend/internal/model"
)

// LoadDuitkuClient builds a DuitkuClient from cfg.Duitku (env-var
// defaults), overlaying any non-empty admin-configured SystemSetting
// values on top. This is called per-request (a handful of indexed SELECTs)
// rather than once at boot, so an admin can rotate the API key or switch
// sandbox/production without a redeploy.
func LoadDuitkuClient(db *gorm.DB, cfg *config.Config) *DuitkuClient {
	client := &DuitkuClient{
		MerchantCode: cfg.Duitku.MerchantCode,
		APIKey:       cfg.Duitku.APIKey,
		BaseURL:      cfg.Duitku.BaseURL,
		CallbackURL:  cfg.Duitku.CallbackURL,
		ReturnURL:    cfg.Duitku.ReturnURL,
	}

	var settings []model.SystemSetting
	db.Where("key IN ?", []string{
		"duitku_merchant_code",
		"duitku_api_key",
		"duitku_base_url",
		"duitku_callback_url",
		"duitku_return_url",
	}).Find(&settings)

	for _, s := range settings {
		if s.Value == "" {
			continue
		}
		switch s.Key {
		case "duitku_merchant_code":
			client.MerchantCode = s.Value
		case "duitku_api_key":
			client.APIKey = s.Value
		case "duitku_base_url":
			client.BaseURL = s.Value
		case "duitku_callback_url":
			client.CallbackURL = s.Value
		case "duitku_return_url":
			client.ReturnURL = s.Value
		}
	}

	return client
}
