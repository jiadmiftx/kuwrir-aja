package pricing

import (
	"testing"
	"time"
)

func at(hour, minute int) time.Time {
	return time.Date(2026, 1, 1, hour, minute, 0, 0, time.UTC)
}

func TestIsVisibleNow_AlwaysVisibleWhenUnset(t *testing.T) {
	if !isVisibleAt(nil, nil, at(3, 0)) {
		t.Error("expected always visible when both bounds are nil")
	}
}

func TestIsVisibleNow_SameDayWindow(t *testing.T) {
	from, until := 9*60, 17*60 // 09:00-17:00

	if !isVisibleAt(&from, &until, at(12, 0)) {
		t.Error("expected 12:00 to be inside 09:00-17:00")
	}
	if isVisibleAt(&from, &until, at(8, 0)) {
		t.Error("expected 08:00 to be outside 09:00-17:00")
	}
	if isVisibleAt(&from, &until, at(18, 0)) {
		t.Error("expected 18:00 to be outside 09:00-17:00")
	}
}

func TestIsVisibleNow_OvernightWindow(t *testing.T) {
	from, until := 22*60, 2*60 // 22:00-02:00, crosses midnight

	if !isVisibleAt(&from, &until, at(1, 0)) {
		t.Error("expected 01:00 to be inside 22:00-02:00")
	}
	if !isVisibleAt(&from, &until, at(23, 0)) {
		t.Error("expected 23:00 to be inside 22:00-02:00")
	}
	if isVisibleAt(&from, &until, at(12, 0)) {
		t.Error("expected 12:00 to be outside 22:00-02:00")
	}
}
