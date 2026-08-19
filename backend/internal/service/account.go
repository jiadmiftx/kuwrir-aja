package service

import (
	"fmt"
	"time"

	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

// DeleteUserAccount soft-deletes a User and its role-specific profile
// (Merchant/Driver), used both by the self-service "delete my account"
// endpoint and by the admin panel's superadmin-only user deletion. Returns
// a non-empty blockReason (safe to show the caller) instead of an error
// when the account is still holding money the platform owes or is owed —
// deletion must wait until that's settled.
func DeleteUserAccount(db *gorm.DB, user model.User) (blockReason string, err error) {
	var driver model.Driver
	hasDriver := db.Where("user_id = ?", user.ID).First(&driver).Error == nil
	if hasDriver && driver.CodHolding > 0 {
		return "Masih ada saldo COD di tangan driver, setor dulu sebelum menghapus akun", nil
	}

	// A person can hold up to one Wallet row per role (customer/driver/
	// merchant) — block deletion if ANY of them still has money, not just
	// whichever role's row happens to be found first.
	var walletCount int64
	db.Model(&model.Wallet{}).Where("user_id = ? AND balance > 0", user.ID).Count(&walletCount)
	if walletCount > 0 {
		return "Masih ada saldo wallet, tarik/settle dulu sebelum menghapus akun", nil
	}

	// Free up the phone/email for reuse — the unique indexes on User.Phone
	// and User.Email are plain (not scoped to deleted_at), so a soft-deleted
	// row still blocks a new registration with the same phone/email unless
	// its identity fields are tombstoned first.
	tombstone := fmt.Sprintf("deleted-%d-%s", time.Now().UnixNano(), user.ID.String())
	updates := map[string]interface{}{
		"is_active": false,
		"fcm_token": "",
		"phone":     tombstone,
	}
	if user.Email != "" {
		updates["email"] = tombstone
	}
	if err := db.Model(&user).Updates(updates).Error; err != nil {
		return "", err
	}

	db.Where("user_id = ?", user.ID).Delete(&model.Address{})
	db.Where("user_id = ?", user.ID).Delete(&model.UserRole{})

	var merchant model.Merchant
	if db.Where("user_id = ?", user.ID).First(&merchant).Error == nil {
		db.Model(&merchant).Update("is_active", false)
		db.Delete(&merchant)
	}
	if hasDriver {
		db.Delete(&driver)
	}

	if err := db.Delete(&user).Error; err != nil {
		return "", err
	}
	return "", nil
}
