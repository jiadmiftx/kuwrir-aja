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
