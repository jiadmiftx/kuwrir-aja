package service

import "sync"

// SupportEvent is broadcast whenever a new support message is sent (by the
// customer or by an admin's reply), so the customer's open SSE connection
// can react instead of polling. Trigger-only, same shape as ChatEvent.
type SupportEvent struct {
	UserID string `json:"user_id"`
}

var (
	supportEventMu   sync.Mutex
	supportEventSubs = map[string][]chan SupportEvent{}
)

// SubscribeSupportEvents registers a new listener for the given user ID's
// support thread. The returned unsubscribe func must be called (typically
// via defer) once the caller stops listening.
func SubscribeSupportEvents(userID string) (<-chan SupportEvent, func()) {
	ch := make(chan SupportEvent, 1)

	supportEventMu.Lock()
	supportEventSubs[userID] = append(supportEventSubs[userID], ch)
	supportEventMu.Unlock()

	unsubscribe := func() {
		supportEventMu.Lock()
		defer supportEventMu.Unlock()
		subs := supportEventSubs[userID]
		for i, c := range subs {
			if c == ch {
				supportEventSubs[userID] = append(subs[:i], subs[i+1:]...)
				break
			}
		}
		if len(supportEventSubs[userID]) == 0 {
			delete(supportEventSubs, userID)
		}
		close(ch)
	}
	return ch, unsubscribe
}

// PublishSupportEvent notifies every open subscriber for userID. Sends are
// non-blocking (buffered channel, size 1).
func PublishSupportEvent(userID string) {
	supportEventMu.Lock()
	subs := append([]chan SupportEvent{}, supportEventSubs[userID]...)
	supportEventMu.Unlock()

	event := SupportEvent{UserID: userID}
	for _, ch := range subs {
		select {
		case ch <- event:
		default:
		}
	}
}
