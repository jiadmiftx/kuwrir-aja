export function formatIDR(amount: number) {
  return "Rp" + Math.round(amount).toLocaleString("id-ID");
}
