package middleware

import "strings"

// featureNames maps a route's identifying path segment (the resource name
// right after /api/v1, or after /admin | /driver | /my-store when those act
// as a role namespace) to a human-readable feature label shown in the admin
// panel's audit log. Keyed by resource, not by role — the log's ActorRole
// column already distinguishes who made the request.
var featureNames = map[string]string{
	"orders":              "Pesanan",
	"merchant-orders":     "Pesanan Toko",
	"driver-orders":       "Pesanan Driver",
	"service-orders":      "Order Jasa",
	"addresses":           "Alamat",
	"merchants":           "Merchant",
	"drivers":             "Driver",
	"customers":           "Customer",
	"users":               "Akun Pengguna",
	"admins":              "Admin",
	"promotions":          "Promosi",
	"delivery-zones":      "Zona Pengiriman",
	"food-categories":     "Kategori Makanan",
	"banners":             "Banner",
	"banner":              "Banner Toko",
	"whatsapp":            "WhatsApp Gateway",
	"audit-logs":          "Audit Log",
	"settings":            "Pengaturan",
	"settlements":         "Settlement",
	"refunds":             "Refund",
	"withdrawals":         "Penarikan Dana",
	"driver-applications": "Pengajuan Driver",
	"revenue":             "Laporan Pendapatan",
	"dashboard":           "Dashboard",
	"dashboard-summary":   "Dashboard Toko",
	"today-summary":       "Dashboard Toko",
	"pos":                 "Kasir (POS)",
	"categories":          "Kategori Toko",
	"products":            "Produk",
	"variants":            "Varian Produk",
	"logo":                "Logo Toko",
	"wallet":              "Dompet",
	"cod":                 "Setoran COD",
	"apply":               "Pendaftaran Driver",
	"application":         "Pendaftaran Driver",
	"agreement":           "Perjanjian Kemitraan",
	"status":              "Status Driver",
	"payment":             "Pembayaran",
	"support":             "Support / CS",
	"auth":                "Autentikasi",
	"toggle-open":         "Operasional Toko",
	"toggle-self-deliver": "Operasional Toko",
	"self-delivery-fee":   "Operasional Toko",
	"my-deliveries":       "Pengiriman Toko",
	"zone":                "Zona Pengiriman",
}

// namespaces are top-level path segments that act as a role/scope prefix
// rather than a feature themselves — for these, the feature comes from the
// next segment instead (e.g. "/admin/orders" -> "orders", not "admin").
var namespaces = map[string]bool{
	"admin":    true,
	"driver":   true,
	"my-store": true,
}

// DeriveFeature turns a Gin route pattern (c.FullPath(), e.g.
// "/api/v1/admin/orders/:id") into a human-readable feature name for the
// audit log's Fitur column. Falls back to a title-cased version of the
// resource segment if it isn't in featureNames, and to "Lainnya" if the
// path has no usable segment at all.
func DeriveFeature(path string) string {
	trimmed := strings.TrimPrefix(path, "/api/v1")
	segs := []string{}
	for _, s := range strings.Split(trimmed, "/") {
		if s != "" {
			segs = append(segs, s)
		}
	}
	if len(segs) == 0 {
		return "Lainnya"
	}

	key := segs[0]
	if namespaces[segs[0]] && len(segs) > 1 {
		key = segs[1]
	}

	if name, ok := featureNames[key]; ok {
		return name
	}
	return strings.Title(strings.ReplaceAll(key, "-", " "))
}
