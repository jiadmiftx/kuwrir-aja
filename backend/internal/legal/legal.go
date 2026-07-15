// Package legal renders the platform's legal documents (customer T&C,
// driver/merchant partnership agreements) with the signer's own data filled
// in, so the app can show a finished contract instead of a static PDF.
//
// The .md files under docs/ are the single source of truth — they mirror the
// root-level SYARAT_KETENTUAN_CUSTOMER.md / PERJANJIAN_KEMITRAAN_*.md files
// in the repo. If those root docs change, copy the changes into docs/ too.
package legal

import (
	"embed"
	"strings"
	"time"
)

//go:embed docs/*.md
var docsFS embed.FS

// CurrentVersion is stamped onto every acceptance record (Driver/Merchant/User)
// so admin can tell which revision of the agreement a signer actually agreed to,
// even if the template text is edited later.
const CurrentVersion = "1.0"

// ContactInfo holds the admin-editable support details substituted into
// customer_terms.md — backed by model.SystemSetting rows so it can change
// without a redeploy.
type ContactInfo struct {
	WhatsApp string
	Email    string
	Hours    string
}

func mustRead(name string) string {
	b, err := docsFS.ReadFile("docs/" + name)
	if err != nil {
		panic(err) // programmer error: docs/ file missing or renamed
	}
	return string(b)
}

func render(tmpl string, tokens map[string]string) string {
	pairs := make([]string, 0, len(tokens)*2)
	for k, v := range tokens {
		pairs = append(pairs, "{{"+k+"}}", v)
	}
	return strings.NewReplacer(pairs...).Replace(tmpl)
}

func today() string {
	months := []string{"", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
		"Juli", "Agustus", "September", "Oktober", "November", "Desember"}
	now := time.Now()
	return now.Format("2") + " " + months[int(now.Month())] + " " + now.Format("2006")
}

// RenderCustomerTerms fills the support-contact tokens into the customer ToS.
func RenderCustomerTerms(contact ContactInfo) string {
	return render(mustRead("customer_terms.md"), map[string]string{
		"WA_CS":       contact.WhatsApp,
		"EMAIL_CS":    contact.Email,
		"JAM_LAYANAN": contact.Hours,
	})
}

// DriverSignerData is the driver's own info, as collected during onboarding.
type DriverSignerData struct {
	FullName     string
	NIK          string
	LicenseNo    string // Nomor SIM
	VehiclePlate string
	Phone        string
	Address      string
}

// RenderDriverAgreement fills the driver's personal data into the partnership
// agreement template.
func RenderDriverAgreement(d DriverSignerData) string {
	return render(mustRead("driver_agreement.md"), map[string]string{
		"NAMA_LENGKAP": d.FullName,
		"NIK":          d.NIK,
		"NOMOR_SIM":    d.LicenseNo,
		"PLAT_NOMOR":   d.VehiclePlate,
		"NOMOR_HP":     d.Phone,
		"ALAMAT":       d.Address,
		"TANGGAL":      today(),
	})
}

// MerchantSignerData is the merchant owner's own info, as collected during registration.
type MerchantSignerData struct {
	OwnerName string
	NIK       string
	StoreName string
	Phone     string
	Address   string // store address
}

// RenderMerchantAgreement fills the merchant's own data into the partnership
// agreement template.
func RenderMerchantAgreement(m MerchantSignerData) string {
	return render(mustRead("merchant_agreement.md"), map[string]string{
		"NAMA_LENGKAP": m.OwnerName,
		"NIK":          m.NIK,
		"NAMA_TOKO":    m.StoreName,
		"NOMOR_HP":     m.Phone,
		"ALAMAT":       m.Address,
		"TANGGAL":      today(),
	})
}
