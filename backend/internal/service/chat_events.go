package service

import "sync"

// ChatEvent is broadcast whenever a new order-chat message is sent, so an
// open SSE connection watching that order (either the customer's or the
// driver's chat screen) can react instead of polling. Trigger-only — no
// message payload — the client already knows how to refetch the full
// thread via GetChat, so this mirrors OrderStatusEvent's shape rather than
// duplicating message serialization here.
type ChatEvent struct {
	OrderID string `json:"order_id"`
}

var (
	chatEventMu   sync.Mutex
	chatEventSubs = map[string][]chan ChatEvent{}
)

// SubscribeChatEvents registers a new listener for the given order ID's
// chat. The returned unsubscribe func must be called (typically via defer)
// once the caller stops listening — it removes and closes the channel so a
// disconnected SSE client can never leak a goroutine or a slot in the map.
func SubscribeChatEvents(orderID string) (<-chan ChatEvent, func()) {
	ch := make(chan ChatEvent, 1)

	chatEventMu.Lock()
	chatEventSubs[orderID] = append(chatEventSubs[orderID], ch)
	chatEventMu.Unlock()

	unsubscribe := func() {
		chatEventMu.Lock()
		defer chatEventMu.Unlock()
		subs := chatEventSubs[orderID]
		for i, c := range subs {
			if c == ch {
				chatEventSubs[orderID] = append(subs[:i], subs[i+1:]...)
				break
			}
		}
		if len(chatEventSubs[orderID]) == 0 {
			delete(chatEventSubs, orderID)
		}
		close(ch)
	}
	return ch, unsubscribe
}

// PublishChatEvent notifies every open subscriber for orderID. Sends are
// non-blocking (buffered channel, size 1) — a subscriber that's momentarily
// busy just gets its next heartbeat/fallback poll to catch up, this never
// blocks the handler that's publishing.
func PublishChatEvent(orderID string) {
	chatEventMu.Lock()
	subs := append([]chan ChatEvent{}, chatEventSubs[orderID]...)
	chatEventMu.Unlock()

	event := ChatEvent{OrderID: orderID}
	for _, ch := range subs {
		select {
		case ch <- event:
		default:
		}
	}
}
