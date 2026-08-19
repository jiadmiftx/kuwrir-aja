// migrate-merchant-wallets is a one-off, manually-run tool — not part of
// the server's normal startup — that fixes the fallout of a bug where
// merchant order earnings were credited to a wallet keyed by
// Order.MerchantID (a Merchant row's own primary key) instead of
// Merchant.UserID (the account that actually owns the store). See
// service.CreditMerchantWallet's doc comment for the root cause; this tool
// cleans up whatever such "phantom" wallets already exist.
//
// Defaults to a dry run that only prints what it would do. Pass -apply to
// actually merge each phantom wallet's balance/ledger into the correct
// wallet and delete the phantom row.
//
//	go run ./cmd/migrate-merchant-wallets            # preview only
//	go run ./cmd/migrate-merchant-wallets -apply     # actually migrate
package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/google/uuid"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/kuwrir-platform/backend/internal/config"
	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/service"
)

type phantomWallet struct {
	WalletID       uuid.UUID
	Balance        float64
	TotalEarned    float64
	TotalWithdrawn float64
	MerchantID     uuid.UUID
	MerchantName   string
	RealUserID     uuid.UUID
}

func main() {
	apply := flag.Bool("apply", false, "actually perform the migration (default: dry run, preview only)")
	flag.Parse()

	cfg := config.Load()
	db, err := gorm.Open(postgres.Open(cfg.Database.DSN()), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	var phantoms []phantomWallet
	err = db.Raw(`
		SELECT w.id AS wallet_id, w.balance, w.total_earned, w.total_withdrawn,
		       m.id AS merchant_id, m.name AS merchant_name, m.user_id AS real_user_id
		FROM wallets w
		JOIN merchants m ON m.id = w.user_id
	`).Scan(&phantoms).Error
	if err != nil {
		log.Fatalf("failed to find phantom wallets: %v", err)
	}

	if len(phantoms) == 0 {
		fmt.Println("No phantom merchant wallets found — nothing to migrate.")
		return
	}

	fmt.Printf("Found %d phantom wallet(s):\n\n", len(phantoms))
	for _, p := range phantoms {
		fmt.Printf("  merchant %q (%s)\n    phantom wallet %s -> balance=%.0f total_earned=%.0f total_withdrawn=%.0f\n    will merge into real owner wallet (user_id=%s)\n\n",
			p.MerchantName, p.MerchantID, p.WalletID, p.Balance, p.TotalEarned, p.TotalWithdrawn, p.RealUserID)
	}

	if !*apply {
		fmt.Println("Dry run only — no changes made. Re-run with -apply to migrate.")
		return
	}

	for _, p := range phantoms {
		err := db.Transaction(func(tx *gorm.DB) error {
			real, err := service.GetOrCreateWallet(tx, p.RealUserID, model.RoleMerchant)
			if err != nil {
				return err
			}
			if err := tx.Model(real).Updates(map[string]interface{}{
				"balance":         real.Balance + p.Balance,
				"total_earned":    real.TotalEarned + p.TotalEarned,
				"total_withdrawn": real.TotalWithdrawn + p.TotalWithdrawn,
			}).Error; err != nil {
				return err
			}
			if err := tx.Model(&model.WalletTransaction{}).
				Where("wallet_id = ?", p.WalletID).
				Update("wallet_id", real.ID).Error; err != nil {
				return err
			}
			return tx.Unscoped().Delete(&model.Wallet{}, "id = ?", p.WalletID).Error
		})
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to migrate phantom wallet %s (merchant %s): %v\n", p.WalletID, p.MerchantName, err)
			continue
		}
		fmt.Printf("Migrated phantom wallet for merchant %q\n", p.MerchantName)
	}
}
