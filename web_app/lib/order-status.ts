const LABELS: Record<string, string> = {
  pending: "Menunggu Konfirmasi",
  confirmed: "Dikonfirmasi",
  preparing: "Sedang Disiapkan",
  ready: "Siap Diambil",
  picked_up: "Sedang Diantar",
  delivered: "Selesai",
  cancelled: "Dibatalkan",
};

export function orderStatusLabel(status: string) {
  return LABELS[status] ?? status;
}

const ACTIVE_STATUSES = ["pending", "confirmed", "preparing", "ready", "picked_up"];

export function isActiveOrder(status: string) {
  return ACTIVE_STATUSES.includes(status);
}

// One semantic-color source for every status badge on the site (order list
// card, order detail header) so a color never means something different from
// screen to screen — mirrors customer_app's _StatusBadge tone mapping.
export type StatusTone = "accent" | "danger" | "warning" | "info" | "neutral";

export function orderStatusTone(status: string): StatusTone {
  switch (status) {
    case "delivered":
      return "accent";
    case "cancelled":
      return "danger";
    case "pending":
    case "preparing":
    case "ready":
      return "warning";
    case "confirmed":
    case "picked_up":
      return "info";
    default:
      return "neutral";
  }
}

const TONE_CLASSES: Record<StatusTone, string> = {
  accent: "bg-(--color-accent-soft) text-(--color-accent)",
  danger: "bg-(--color-danger-soft) text-(--color-danger)",
  warning: "bg-(--color-warning-soft) text-(--color-warning)",
  info: "bg-(--color-info-soft) text-(--color-info)",
  neutral: "bg-(--color-border-soft) text-(--color-ink-faint)",
};

export function orderStatusToneClasses(status: string) {
  return TONE_CLASSES[orderStatusTone(status)];
}

// Condensed 4-step view of the 6-status state machine (placed → prepared →
// on the way → delivered) — mirrors customer_app's _HorizontalTracker, which
// deliberately doesn't show every backend status, just what a customer needs
// to see at a glance.
export const ORDER_PROGRESS_STEPS = ["Dipesan", "Diproses", "Diantar", "Selesai"] as const;

export function orderProgressStepIndex(status: string): number {
  switch (status) {
    case "confirmed":
    case "preparing":
      return 1;
    case "ready":
    case "picked_up":
      return 2;
    case "delivered":
      return 3;
    case "pending":
    default:
      return 0;
  }
}

// Chat only makes sense once the merchant has actually accepted the order
// (and until it's finished) — matches order_tracking_screen.dart's `canChat`.
const CHATTABLE_STATUSES = ["confirmed", "preparing", "ready", "picked_up"];

export function canOrderChat(status: string) {
  return CHATTABLE_STATUSES.includes(status);
}
