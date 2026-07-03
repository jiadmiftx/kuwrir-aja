package pricing

import (
	"math"
	"testing"
)

// A roughly 1km x 1km square centered near (-8.60, 116.10), for boundary
// distance sanity checks at a scale representative of a kecamatan.
const squareGeoJSON = `{"type":"Polygon","coordinates":[[[116.095,-8.605],[116.105,-8.605],[116.105,-8.595],[116.095,-8.595],[116.095,-8.605]]]}`

func TestIsInsideShape_Polygon(t *testing.T) {
	geo := squareGeoJSON
	shape := ZoneShape{BoundaryGeoJSON: &geo}

	if !IsInsideShape(-8.600, 116.100, shape) {
		t.Error("expected center point to be inside the polygon")
	}
	if IsInsideShape(-8.700, 116.100, shape) {
		t.Error("expected far point to be outside the polygon")
	}
}

func TestIsInsideShape_Radius(t *testing.T) {
	shape := ZoneShape{Lat: -8.600, Lng: 116.100, RadiusKm: 3}

	if !IsInsideShape(-8.600, 116.100, shape) {
		t.Error("expected center point to be inside the radius")
	}
	if !IsInsideShape(-8.610, 116.100, shape) {
		t.Error("expected point ~1.1km away to be inside a 3km radius")
	}
	if IsInsideShape(-8.700, 116.100, shape) {
		t.Error("expected point ~11km away to be outside a 3km radius")
	}
}

func TestDistanceToShapeBoundaryKm_Radius(t *testing.T) {
	shape := ZoneShape{Lat: -8.600, Lng: 116.100, RadiusKm: 3}

	if d := DistanceToShapeBoundaryKm(-8.600, 116.100, shape); d != 0 {
		t.Errorf("expected 0 distance when inside, got %f", d)
	}

	// ~0.1 deg lat ≈ 11.06km from center, minus 3km radius ≈ 8.06km excess.
	got := DistanceToShapeBoundaryKm(-8.700, 116.100, shape)
	want := 8.06
	if math.Abs(got-want) > 0.2 {
		t.Errorf("expected ~%.2fkm excess, got %.2fkm", want, got)
	}
}

func TestDistanceToShapeBoundaryKm_Polygon(t *testing.T) {
	geo := squareGeoJSON
	shape := ZoneShape{BoundaryGeoJSON: &geo}

	// DistanceToShapeBoundaryKm always measures to the nearest edge — it
	// does not special-case points already inside. Callers check
	// IsInsideShape first (see priceDropoff) and only call this for the
	// excess-distance calculation once a point is known to be outside.

	// Point due south of the square's bottom edge (lat -8.605) by ~0.01deg
	// (~1.1km), directly below the square's longitude range, so the
	// nearest edge distance should be close to that ~1.1km straight-line gap.
	got := DistanceToShapeBoundaryKm(-8.615, 116.100, shape)
	want := 1.1
	if math.Abs(got-want) > 0.2 {
		t.Errorf("expected ~%.2fkm to nearest edge, got %.2fkm", want, got)
	}
}
