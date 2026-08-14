package service

import "sync"

// OrderStatusEvent is broadcast whenever an order's status changes, so an
// open SSE connection watching that order (customer_app's order tracking
// screen) can react the instant a merchant/driver action lands instead of
// the client having to poll every few seconds. Mirrors PaymentEvent/
// SubscribePaymentEvents/PublishPaymentEvent exactly — same pattern, a
// different field.
type OrderStatusEvent struct {
	OrderID string `json:"order_id"`
	Status  string `json:"status"`
}

var (
	orderStatusEventMu   sync.Mutex
	orderStatusEventSubs = map[string][]chan OrderStatusEvent{}
)

// SubscribeOrderStatusEvents registers a new listener for the given order
// ID. The returned unsubscribe func must be called (typically via defer)
// once the caller stops listening — it removes and closes the channel so a
// disconnected SSE client can never leak a goroutine or a slot in the map.
func SubscribeOrderStatusEvents(orderID string) (<-chan OrderStatusEvent, func()) {
	ch := make(chan OrderStatusEvent, 1)

	orderStatusEventMu.Lock()
	orderStatusEventSubs[orderID] = append(orderStatusEventSubs[orderID], ch)
	orderStatusEventMu.Unlock()

	unsubscribe := func() {
		orderStatusEventMu.Lock()
		defer orderStatusEventMu.Unlock()
		subs := orderStatusEventSubs[orderID]
		for i, c := range subs {
			if c == ch {
				orderStatusEventSubs[orderID] = append(subs[:i], subs[i+1:]...)
				break
			}
		}
		if len(orderStatusEventSubs[orderID]) == 0 {
			delete(orderStatusEventSubs, orderID)
		}
		close(ch)
	}
	return ch, unsubscribe
}

// PublishOrderStatusEvent notifies every open subscriber for orderID. Sends
// are non-blocking (buffered channel, size 1) — a subscriber that's
// momentarily busy just gets its next heartbeat/poll to catch up, this
// never blocks the handler that's publishing.
func PublishOrderStatusEvent(orderID, status string) {
	orderStatusEventMu.Lock()
	subs := append([]chan OrderStatusEvent{}, orderStatusEventSubs[orderID]...)
	orderStatusEventMu.Unlock()

	event := OrderStatusEvent{OrderID: orderID, Status: status}
	for _, ch := range subs {
		select {
		case ch <- event:
		default:
		}
	}
}
