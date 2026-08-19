package service

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

// GetWalletTransactions returns the most recent ledger entries for a
// user's role-scoped wallet. Shared by driver/merchant/customer wallet handlers.
func GetWalletTransactions(db *gorm.DB, userID uuid.UUID, role model.Role) (*model.Wallet, []model.WalletTransaction, error) {
	wallet, err := GetOrCreateWallet(db, userID, role)
	if err != nil {
		return nil, nil, err
	}

	var txs []model.WalletTransaction
	if err := db.Where("wallet_id = ?", wallet.ID).
		Order("created_at DESC").
		Limit(50).
		Find(&txs).Error; err != nil {
		return nil, nil, err
	}
	return wallet, txs, nil
}

// WithdrawResult mirrors what the HTTP handlers need to report back.
type WithdrawResult struct {
	Withdrawal *model.WithdrawalRequest
	Status     string
}

// ProcessWithdrawal validates balance, saves/falls-back-to a BankAccount,
// calls Duitku disbursement, records the WithdrawalRequest, and debits the
// wallet only on synchronous SUCCESS (matching the existing behavior —
// "processing" withdrawals are debited later by the disbursement
// reconciliation sweeper). If bankCode/accountNumber/accountName are all
// empty, falls back to the user's saved BankAccount; if provided, they're
// also upserted into BankAccount so future withdrawals can omit them.
func ProcessWithdrawal(db *gorm.DB, duitku *DuitkuClient, userID uuid.UUID, role model.Role, amount float64, bankCode, bankAccountNumber, bankAccountName string) (*WithdrawResult, error) {
	if bankCode == "" && bankAccountNumber == "" && bankAccountName == "" {
		var saved model.BankAccount
		if err := db.Where("user_id = ? AND role = ?", userID, role).First(&saved).Error; err != nil {
			return nil, fmt.Errorf("no bank account provided or saved")
		}
		bankCode, bankAccountNumber, bankAccountName = saved.BankCode, saved.AccountNumber, saved.AccountName
	} else {
		var saved model.BankAccount
		err := db.Where("user_id = ? AND role = ?", userID, role).First(&saved).Error
		if err == gorm.ErrRecordNotFound {
			db.Create(&model.BankAccount{UserID: userID, Role: role, BankCode: bankCode, AccountNumber: bankAccountNumber, AccountName: bankAccountName})
		} else if err == nil {
			db.Model(&saved).Updates(map[string]interface{}{
				"bank_code": bankCode, "account_number": bankAccountNumber, "account_name": bankAccountName,
			})
		}
	}

	wallet, err := GetOrCreateWallet(db, userID, role)
	if err != nil {
		return nil, fmt.Errorf("failed to get wallet: %w", err)
	}
	if wallet.Balance < amount {
		return nil, fmt.Errorf("insufficient wallet balance")
	}

	disbRef := fmt.Sprintf("WD-%s-%d", wallet.ID.String()[:8], time.Now().UnixMilli())
	result, err := duitku.Disburse(disbRef, bankCode, bankAccountNumber, bankAccountName, int64(amount))
	if err != nil {
		return nil, fmt.Errorf("disbursement failed: %w", err)
	}

	status := "processing"
	if result.Status == "SUCCESS" {
		status = "success"
	}

	wReq := model.WithdrawalRequest{
		WalletID:          wallet.ID,
		Amount:            amount,
		BankCode:          bankCode,
		BankAccountNumber: bankAccountNumber,
		BankAccountName:   bankAccountName,
		Status:            status,
		DisbursementRef:   result.DisbursementRef,
	}
	if err := db.Create(&wReq).Error; err != nil {
		return nil, fmt.Errorf("failed to record withdrawal: %w", err)
	}

	if status == "success" {
		tx := db.Begin()
		notes := fmt.Sprintf("Withdrawal to %s %s", bankCode, bankAccountNumber)
		if err := DebitWallet(tx, userID, role, amount, "withdrawal", nil, notes); err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("failed to debit wallet: %w", err)
		}
		tx.Commit()
	}

	return &WithdrawResult{Withdrawal: &wReq, Status: status}, nil
}
