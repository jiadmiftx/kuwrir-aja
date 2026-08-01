package service

import "sync"

// PaymentEvent is broadcast whenever an order's payment_status changes, so
// an open SSE connection watching that order can react the instant Duitku's
// callback lands instead of the client having to poll for it.
type PaymentEvent struct {
	OrderID       string `json:"order_id"`
	PaymentStatus string `json:"payment_status"`
}

var (
	paymentEventMu   sync.Mutex
	paymentEventSubs = map[string][]chan PaymentEvent{}
)

// SubscribePaymentEvents registers a new listener for the given order ID.
// The returned unsubscribe func must be called (typically via defer) once
// the caller stops listening — it removes and closes the channel so a
// disconnected SSE client can never leak a goroutine or a slot in the map.
func SubscribePaymentEvents(orderID string) (<-chan PaymentEvent, func()) {
	ch := make(chan PaymentEvent, 1)

	paymentEventMu.Lock()
	paymentEventSubs[orderID] = append(paymentEventSubs[orderID], ch)
	paymentEventMu.Unlock()

	unsubscribe := func() {
		paymentEventMu.Lock()
		defer paymentEventMu.Unlock()
		subs := paymentEventSubs[orderID]
		for i, c := range subs {
			if c == ch {
				paymentEventSubs[orderID] = append(subs[:i], subs[i+1:]...)
				break
			}
		}
		if len(paymentEventSubs[orderID]) == 0 {
			delete(paymentEventSubs, orderID)
		}
		close(ch)
	}
	return ch, unsubscribe
}

// PublishPaymentEvent notifies every open subscriber for orderID. Sends are
// non-blocking (buffered channel, size 1) — a subscriber that's momentarily
// busy just gets its next heartbeat/poll to catch up, this never blocks the
// webhook handler that's publishing.
func PublishPaymentEvent(orderID, status string) {
	paymentEventMu.Lock()
	subs := append([]chan PaymentEvent{}, paymentEventSubs[orderID]...)
	paymentEventMu.Unlock()

	event := PaymentEvent{OrderID: orderID, PaymentStatus: status}
	for _, ch := range subs {
		select {
		case ch <- event:
		default:
		}
	}
}
