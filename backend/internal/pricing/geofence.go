package pricing

import (
	"encoding/json"
	"math"
)

// geoJSONPolygon is the subset of GeoJSON Polygon we need.
type geoJSONPolygon struct {
	Type        string          `json:"type"`
	Coordinates [][][2]float64  `json:"coordinates"` // [ring][point][lng, lat]
}

// PointInPolygon returns true if (lat, lng) is inside the GeoJSON Polygon string.
// Uses the ray casting algorithm. GeoJSON coordinates are [longitude, latitude].
// Falls back to false on any parse error.
func PointInPolygon(lat, lng float64, geoJSONStr string) bool {
	var poly geoJSONPolygon
	if err := json.Unmarshal([]byte(geoJSONStr), &poly); err != nil {
		return false
	}
	if poly.Type != "Polygon" || len(poly.Coordinates) == 0 {
		return false
	}
	return rayCast(lng, lat, poly.Coordinates[0]) // outer ring only
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
// the customer's dropoff point. If the zone has a polygon boundary, it uses
// point-in-polygon to determine inside/outside; otherwise falls back to radius.
func DeliveryFeeForDropoff(dropLat, dropLng float64, zone Settings, baseFee, perKmFee float64, radiusKm float64, boundaryGeoJSON *string, merchantLat, merchantLng float64) float64 {
	insideZone := isInsideZone(dropLat, dropLng, merchantLat, merchantLng, radiusKm, boundaryGeoJSON)
	if insideZone {
		return baseFee
	}
	// Outside zone: charge per-km based on distance from merchant to dropoff
	distKm := haversineGeo(merchantLat, merchantLng, dropLat, dropLng)
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
