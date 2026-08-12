package service

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"github.com/kuwrir-platform/backend/internal/config"
)

// RouteResult is the road-following distance/duration between two points, used for driver-facing
// display only — delivery-fee pricing still uses the straight-line haversine distance (see
// handler.go's haversineDistance) so pricing never depends on this external API's availability.
type RouteResult struct {
	DistanceKm  float64
	DurationMin float64
}

type orsDirectionsResponse struct {
	Features []struct {
		Properties struct {
			Summary struct {
				Distance float64 `json:"distance"` // meters
				Duration float64 `json:"duration"` // seconds
			} `json:"summary"`
		} `json:"properties"`
	} `json:"features"`
}

// GetRoadRoute calls OpenRouteService's driving-car directions endpoint for the road-following
// distance/duration between two coordinates. Short timeout since this is called synchronously
// from a driver-facing request handler, not a background job — callers should fall back to the
// haversine distance already on the order if this errors (rate limit, timeout, missing API key).
func GetRoadRoute(cfg config.OpenRouteServiceConfig, originLat, originLng, destLat, destLng float64) (*RouteResult, error) {
	if cfg.APIKey == "" {
		return nil, fmt.Errorf("ORS_API_KEY not configured")
	}

	// ORS expects "lng,lat" order, not "lat,lng".
	q := url.Values{}
	q.Set("api_key", cfg.APIKey)
	q.Set("start", fmt.Sprintf("%f,%f", originLng, originLat))
	q.Set("end", fmt.Sprintf("%f,%f", destLng, destLat))

	reqURL := fmt.Sprintf("%s/v2/directions/driving-car?%s", cfg.BaseURL, q.Encode())

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(reqURL)
	if err != nil {
		return nil, fmt.Errorf("ors request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ors returned status %d", resp.StatusCode)
	}

	var result orsDirectionsResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("ors response decode failed: %w", err)
	}
	if len(result.Features) == 0 {
		return nil, fmt.Errorf("ors returned no route")
	}

	summary := result.Features[0].Properties.Summary
	return &RouteResult{
		DistanceKm:  summary.Distance / 1000,
		DurationMin: summary.Duration / 60,
	}, nil
}
