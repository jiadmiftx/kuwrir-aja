const LABELS: Record<string, string> = {
  topup: "Top Up",
  withdrawal: "Penarikan Dana",
  refund: "Pengembalian Dana",
  adjustment: "Penyesuaian",
  order_earning: "Pendapatan Pesanan",
  cod_deposit: "Setoran COD",
  banner_ad: "Iklan Banner",
};

export function walletCategoryLabel(category: string) {
  return LABELS[category] ?? category;
}
