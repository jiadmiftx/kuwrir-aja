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

// ZoneShape is a single flat-fee area: either a precise polygon boundary, or
// a fallback circle of RadiusKm around (Lat, Lng). A kota with no kecamatan
// configured is priced against a single ZoneShape built from its own
// boundary; a kota with active kecamatan is priced against one ZoneShape per
// kecamatan instead (see flatZoneShapes in the customer order handler) — the
// kota's own shape drops out once it has children.
type ZoneShape struct {
	Lat, Lng        float64
	RadiusKm        float64
	BoundaryGeoJSON *string
}

// IsInsideShape returns true if (lat, lng) falls inside the shape: a polygon
// test when BoundaryGeoJSON is set, otherwise a radius-circle test around
// (Lat, Lng).
func IsInsideShape(lat, lng float64, s ZoneShape) bool {
	if s.BoundaryGeoJSON != nil && *s.BoundaryGeoJSON != "" {
		return PointInPolygon(lat, lng, *s.BoundaryGeoJSON)
	}
	return haversineGeo(s.Lat, s.Lng, lat, lng) <= s.RadiusKm
}

// DistanceToShapeBoundaryKm returns the shortest distance in km from
// (lat, lng) to the shape's edge. Callers should check IsInsideShape first;
// this always measures to the boundary regardless of whether the point is
// inside.
func DistanceToShapeBoundaryKm(lat, lng float64, s ZoneShape) float64 {
	if s.BoundaryGeoJSON != nil && *s.BoundaryGeoJSON != "" {
		return distanceToPolygonBoundaryKm(lat, lng, *s.BoundaryGeoJSON)
	}
	return math.Max(0, haversineGeo(s.Lat, s.Lng, lat, lng)-s.RadiusKm)
}

// distanceToPolygonBoundaryKm finds the minimum distance from (lat, lng) to
// any edge of the polygon/multipolygon's exterior ring(s), using a local
// equirectangular projection (accurate enough at city scale — the same
// small-area assumption already implicit in the haversine calls elsewhere
// in this package).
func distanceToPolygonBoundaryKm(lat, lng float64, geoJSONStr string) float64 {
	var base struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal([]byte(geoJSONStr), &base); err != nil {
		return math.MaxFloat64
	}
	var rings [][][2]float64
	switch base.Type {
	case "Polygon":
		var poly geoJSONPolygon
		if err := json.Unmarshal([]byte(geoJSONStr), &poly); err != nil || len(poly.Coordinates) == 0 {
			return math.MaxFloat64
		}
		rings = [][][2]float64{poly.Coordinates[0]}
	case "MultiPolygon":
		var mp geoJSONMultiPolygon
		if err := json.Unmarshal([]byte(geoJSONStr), &mp); err != nil {
			return math.MaxFloat64
		}
		for _, polygon := range mp.Coordinates {
			if len(polygon) > 0 {
				rings = append(rings, polygon[0])
			}
		}
	default:
		return math.MaxFloat64
	}
	if len(rings) == 0 {
		return math.MaxFloat64
	}

	// Local equirectangular projection centered on the query point: 1 degree
	// latitude ≈ 110.57km, 1 degree longitude ≈ 111.32km * cos(lat).
	const kmPerDegLat = 110.57
	kmPerDegLng := 111.32 * math.Cos(lat*math.Pi/180.0)
	px, py := lng*kmPerDegLng, lat*kmPerDegLat

	minDist := math.MaxFloat64
	for _, ring := range rings {
		n := len(ring)
		for i := 0; i < n; i++ {
			a := ring[i]
			b := ring[(i+1)%n]
			ax, ay := a[0]*kmPerDegLng, a[1]*kmPerDegLat
			bx, by := b[0]*kmPerDegLng, b[1]*kmPerDegLat
			d := distanceToSegmentKm(px, py, ax, ay, bx, by)
			if d < minDist {
				minDist = d
			}
		}
	}
	return minDist
}

// distanceToSegmentKm is the shortest distance from point (px, py) to the
// segment (ax, ay)-(bx, by), all in km on the local projected plane.
func distanceToSegmentKm(px, py, ax, ay, bx, by float64) float64 {
	dx, dy := bx-ax, by-ay
	lenSq := dx*dx + dy*dy
	if lenSq == 0 {
		return math.Hypot(px-ax, py-ay)
	}
	t := ((px-ax)*dx + (py-ay)*dy) / lenSq
	t = math.Max(0, math.Min(1, t))
	closestX, closestY := ax+t*dx, ay+t*dy
	return math.Hypot(px-closestX, py-closestY)
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
