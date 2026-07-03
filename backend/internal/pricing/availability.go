package pricing

import "time"

// IsVisibleNow reports whether a product with the given visibility window
// (minutes since midnight, 0-1439) should show up right now. Both nil means
// always visible. When from > until, the window is treated as crossing
// midnight (e.g. from=1320 (22:00) until=120 (02:00) covers 22:00-02:00).
func IsVisibleNow(from, until *int) bool {
	return isVisibleAt(from, until, time.Now())
}

// isVisibleAt is IsVisibleNow with an injectable clock, so window-wrap
// behavior can be tested deterministically.
func isVisibleAt(from, until *int, at time.Time) bool {
	if from == nil || until == nil {
		return true
	}
	nowMinute := at.Hour()*60 + at.Minute()

	if *from <= *until {
		return nowMinute >= *from && nowMinute <= *until
	}
	// Overnight window.
	return nowMinute >= *from || nowMinute <= *until
}
