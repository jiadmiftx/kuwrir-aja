package service

import (
	"fmt"
	"log"
	"time"

	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/config"
	"github.com/kuwrir-platform/backend/internal/model"
)

// RunWithdrawalReconciliation periodically resolves WithdrawalRequest rows
// stuck in "processing" (Duitku returned PENDING at disbursement time, and
// there's no webhook to tell us when that settles) by polling Duitku's
// status endpoint. Mirrors the ticker pattern used by
// cmd/server's runAuditLogMaintenance / RunOrderSLASweeper.
func RunWithdrawalReconciliation(db *gorm.DB, cfg *config.Config) {
	ticker := time.NewTicker(10 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		reconcileProcessingWithdrawals(db, cfg)
	}
}

func reconcileProcessingWithdrawals(db *gorm.DB, cfg *config.Config) {
	cutoff := time.Now().Add(-2 * time.Minute)

	var pending []model.WithdrawalRequest
	if err := db.Where("status = ? AND created_at < ?", "processing", cutoff).Find(&pending).Error; err != nil {
		log.Printf("reconcileProcessingWithdrawals: query failed: %v", err)
		return
	}

	duitku := LoadDuitkuClient(db, cfg)
	for i := range pending {
		if err := ResolveWithdrawalStatus(db, duitku, &pending[i]); err != nil {
			log.Printf("reconcileProcessingWithdrawals: %s: %v", pending[i].DisbursementRef, err)
		}
	}
}

// ResolveWithdrawalStatus checks Duitku for the current status of a single
// processing withdrawal and, if it has settled, debits the wallet
// (on SUCCESS) or records the failure reason (on FAILED) — the same debit
// logic ProcessWithdrawal already applies for a synchronous SUCCESS.
func ResolveWithdrawalStatus(db *gorm.DB, duitku *DuitkuClient, wr *model.WithdrawalRequest) error {
	result, err := duitku.CheckDisbursementStatus(wr.DisbursementRef)
	if err != nil {
		return fmt.Errorf("check status: %w", err)
	}

	switch result.Status {
	case "SUCCESS":
		var wallet model.Wallet
		if err := db.First(&wallet, "id = ?", wr.WalletID).Error; err != nil {
			return fmt.Errorf("load wallet: %w", err)
		}
		tx := db.Begin()
		notes := fmt.Sprintf("Withdrawal to %s %s (reconciled)", wr.BankCode, wr.BankAccountNumber)
		if err := DebitWallet(tx, wallet.UserID, wr.Amount, "withdrawal", nil, notes); err != nil {
			tx.Rollback()
			return fmt.Errorf("debit wallet: %w", err)
		}
		now := time.Now()
		if err := tx.Model(wr).Updates(map[string]interface{}{"status": "success", "processed_at": &now}).Error; err != nil {
			tx.Rollback()
			return fmt.Errorf("update withdrawal: %w", err)
		}
		return tx.Commit().Error
	case "FAILED":
		now := time.Now()
		return db.Model(wr).Updates(map[string]interface{}{
			"status": "failed", "failed_reason": result.Message, "processed_at": &now,
		}).Error
	default:
		return nil // still pending, try again next sweep
	}
}
