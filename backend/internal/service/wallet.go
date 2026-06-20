package service

import (
	"fmt"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

// GetOrCreateWallet returns the wallet for a user, creating one if it doesn't exist.
func GetOrCreateWallet(tx *gorm.DB, userID uuid.UUID) (*model.Wallet, error) {
	var wallet model.Wallet
	err := tx.Where("user_id = ?", userID).First(&wallet).Error
	if err == gorm.ErrRecordNotFound {
		wallet = model.Wallet{UserID: userID}
		if err = tx.Create(&wallet).Error; err != nil {
			return nil, fmt.Errorf("create wallet: %w", err)
		}
		return &wallet, nil
	}
	return &wallet, err
}

// CreditWallet adds amount to a user's wallet balance and records a ledger entry.
// Must be called inside a DB transaction.
func CreditWallet(tx *gorm.DB, userID uuid.UUID, amount float64, category string, orderID *uuid.UUID, notes string) error {
	wallet, err := GetOrCreateWallet(tx, userID)
	if err != nil {
		return err
	}

	newBalance := wallet.Balance + amount

	if err := tx.Model(wallet).Updates(map[string]interface{}{
		"balance":     newBalance,
		"total_earned": gorm.Expr("total_earned + ?", amount),
	}).Error; err != nil {
		return fmt.Errorf("credit wallet: %w", err)
	}

	entry := model.WalletTransaction{
		WalletID:     wallet.ID,
		OrderID:      orderID,
		Type:         "credit",
		Category:     category,
		Amount:       amount,
		BalanceAfter: newBalance,
		Notes:        notes,
	}
	return tx.Create(&entry).Error
}

// DebitWallet subtracts amount from a user's wallet balance and records a ledger entry.
// Returns error if balance is insufficient. Must be called inside a DB transaction.
func DebitWallet(tx *gorm.DB, userID uuid.UUID, amount float64, category string, notes string) error {
	wallet, err := GetOrCreateWallet(tx, userID)
	if err != nil {
		return err
	}

	if wallet.Balance < amount {
		return fmt.Errorf("insufficient balance: have %.0f, need %.0f", wallet.Balance, amount)
	}

	newBalance := wallet.Balance - amount

	if err := tx.Model(wallet).Updates(map[string]interface{}{
		"balance":        newBalance,
		"total_withdrawn": gorm.Expr("total_withdrawn + ?", amount),
	}).Error; err != nil {
		return fmt.Errorf("debit wallet: %w", err)
	}

	entry := model.WalletTransaction{
		WalletID:     wallet.ID,
		Type:         "debit",
		Category:     category,
		Amount:       amount,
		BalanceAfter: newBalance,
		Notes:        notes,
	}
	return tx.Create(&entry).Error
}
