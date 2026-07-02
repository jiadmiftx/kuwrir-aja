package pricing

import (
	"encoding/json"
	"math"
)

type geoJSONPolygon struct {
	Type        string         `json:"type"`
	Coordinates [][][2]float64 `json:"coordinates"` // [ring][point][lng, lat]
}

type geoJSONMultiPolygon struct {
	Type        string           `json:"type"`
	Coordinates [][][][2]float64 `json:"coordinates"` // [polygon][ring][point][lng, lat]
}

// PointInPolygon returns true if (lat, lng) is inside the GeoJSON Polygon or MultiPolygon string.
// Uses the ray casting algorithm. GeoJSON coordinates are [longitude, latitude].
func PointInPolygon(lat, lng float64, geoJSONStr string) bool {
	var base struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal([]byte(geoJSONStr), &base); err != nil {
		return false
	}
	switch base.Type {
	case "Polygon":
		var poly geoJSONPolygon
		if err := json.Unmarshal([]byte(geoJSONStr), &poly); err != nil || len(poly.Coordinates) == 0 {
			return false
		}
		return rayCast(lng, lat, poly.Coordinates[0])
	case "MultiPolygon":
		var mp geoJSONMultiPolygon
		if err := json.Unmarshal([]byte(geoJSONStr), &mp); err != nil {
			return false
		}
		for _, polygon := range mp.Coordinates {
			if len(polygon) > 0 && rayCast(lng, lat, polygon[0]) {
				return true
			}
		}
	}
	return false
}

// rayCast checks point (x, y) against a ring of [lng, lat] pairs.
func rayCast(x, y float64, ring [][2]float64) bool {
	inside := false
	n := len(ring)
	j := n - 1
	for i := 0; i < n; i++ {
		xi, yi := ring[i][0], ring[i][1]
		xj, yj := ring[j][0], ring[j][1]
		if ((yi > y) != (yj > y)) && (x < (xj-xi)*(y-yi)/(yj-yi)+xi) {
			inside = !inside
		}
		j = i
	}
	return inside
}

// DeliveryFeeForDropoff calculates delivery fee given the merchant's zone and
// the customer's dropoff point. Polygon-based zones use the full merchant→dropoff
// distance as the billable extra. Radius-based zones subtract the radius first.
func DeliveryFeeForDropoff(dropLat, dropLng float64, zone Settings, baseFee, perKmFee float64, radiusKm float64, boundaryGeoJSON *string, merchantLat, merchantLng float64) float64 {
	insideZone := isInsideZone(dropLat, dropLng, merchantLat, merchantLng, radiusKm, boundaryGeoJSON)
	if insideZone {
		return baseFee
	}
	distKm := haversineGeo(merchantLat, merchantLng, dropLat, dropLng)
	if boundaryGeoJSON != nil && *boundaryGeoJSON != "" {
		// polygon zone: polygon IS the boundary, full distance is billable
		return baseFee + distKm*perKmFee
	}
	// radius zone fallback: distance beyond radius is billable
	extraKm := math.Max(0, distKm-radiusKm)
	return baseFee + extraKm*perKmFee
}

func isInsideZone(dropLat, dropLng, merchantLat, merchantLng, radiusKm float64, boundary *string) bool {
	if boundary != nil && *boundary != "" {
		return PointInPolygon(dropLat, dropLng, *boundary)
	}
	// Fallback: check if dropoff is within radius_km of merchant
	dist := haversineGeo(merchantLat, merchantLng, dropLat, dropLng)
	return dist <= radiusKm
}

func haversineGeo(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLng := (lng2 - lng1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	return R * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}
