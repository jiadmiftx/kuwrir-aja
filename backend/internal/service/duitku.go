package service

import (
	"bytes"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type DuitkuClient struct {
	MerchantCode string
	APIKey       string
	BaseURL      string
	CallbackURL  string
	ReturnURL    string
}

// --- Payment Request ---

type DuitkuPaymentRequest struct {
	MerchantCode        string `json:"merchantCode"`
	PaymentAmount       int64  `json:"paymentAmount"`
	MerchantOrderID     string `json:"merchantOrderId"`
	ProductDetails      string `json:"productDetails"`
	CustomerVaName      string `json:"customerVaName"`
	Email               string `json:"email"`
	PaymentMethod       string `json:"paymentMethod"` // VC, QRIS, OV, etc.
	CallbackURL         string `json:"callbackUrl"`
	ReturnURL           string `json:"returnUrl"`
	ExpiryPeriod        int    `json:"expiryPeriod"` // minutes
	Signature           string `json:"signature"`
}

type DuitkuPaymentResponse struct {
	MerchantCode    string `json:"merchantCode"`
	Reference       string `json:"reference"`
	PaymentURL      string `json:"paymentUrl"`
	VaNumber        string `json:"vaNumber"`
	Amount          string `json:"amount"`
	StatusCode      string `json:"statusCode"`
	StatusMessage   string `json:"statusMessage"`
}

// CreatePayment creates a Duitku payment request and returns the payment URL.
func (d *DuitkuClient) CreatePayment(orderID, orderNumber string, amount int64, customerName, email, paymentMethod, productDesc string) (*DuitkuPaymentResponse, error) {
	// Signature: MD5(merchantCode + amount + merchantOrderId + apiKey)
	raw := fmt.Sprintf("%s%d%s%s", d.MerchantCode, amount, orderNumber, d.APIKey)
	sig := fmt.Sprintf("%x", md5.Sum([]byte(raw)))

	returnURL := d.ReturnURL
	if orderID != "" {
		returnURL = fmt.Sprintf("%s/%s", d.ReturnURL, orderID)
	}

	payload := DuitkuPaymentRequest{
		MerchantCode:    d.MerchantCode,
		PaymentAmount:   amount,
		MerchantOrderID: orderNumber,
		ProductDetails:  productDesc,
		CustomerVaName:  customerName,
		Email:           email,
		PaymentMethod:   paymentMethod,
		CallbackURL:     d.CallbackURL,
		ReturnURL:       returnURL,
		ExpiryPeriod:    60, // 1 hour
		Signature:       sig,
	}

	body, _ := json.Marshal(payload)
	resp, err := http.Post(d.BaseURL+"/api/merchant/v2/inquiry", "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("duitku request: %w", err)
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	var result DuitkuPaymentResponse
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, fmt.Errorf("duitku response parse: %w", err)
	}
	if result.StatusCode != "00" {
		return nil, fmt.Errorf("duitku error: %s", result.StatusMessage)
	}
	return &result, nil
}

// VerifyCallbackSignature validates the Duitku payment callback.
// Signature: MD5(merchantCode + amount + merchantOrderId + apiKey)
func (d *DuitkuClient) VerifyCallbackSignature(amount, merchantOrderID, signature string) bool {
	raw := fmt.Sprintf("%s%s%s%s", d.MerchantCode, amount, merchantOrderID, d.APIKey)
	expected := fmt.Sprintf("%x", md5.Sum([]byte(raw)))
	return expected == signature
}

// --- Disbursement ---

type DuitkuDisbursementRequest struct {
	UserID          string `json:"userId"`
	Amount          int64  `json:"amount"`
	AmountTransfer  int64  `json:"amountTransfer"`
	Bank            string `json:"bank"`
	BankAccount     string `json:"bankAccount"`
	BankAccountName string `json:"bankAccountName"`
	DisbursementRef string `json:"disbursementRef"` // unique ID from our side
	Timestamp       string `json:"timestamp"`
	Signature       string `json:"signature"`
}

type DuitkuDisbursementResponse struct {
	DisbursementRef string `json:"disbursementRef"`
	Status          string `json:"status"` // SUCCESS, PENDING, FAILED
	Message         string `json:"message"`
}

// Disburse sends money to a bank account via Duitku disbursement API.
// Returns the Duitku disbursement reference on success.
func (d *DuitkuClient) Disburse(ref, bankCode, accountNumber, accountName string, amount int64) (*DuitkuDisbursementResponse, error) {
	timestamp := fmt.Sprintf("%d", time.Now().UnixMilli())
	// Signature: MD5(userId + amount + disbursementRef + timestamp + apiKey)
	raw := fmt.Sprintf("%s%d%s%s%s", d.MerchantCode, amount, ref, timestamp, d.APIKey)
	sig := fmt.Sprintf("%x", md5.Sum([]byte(raw)))

	payload := DuitkuDisbursementRequest{
		UserID:          d.MerchantCode,
		Amount:          amount,
		AmountTransfer:  amount,
		Bank:            bankCode,
		BankAccount:     accountNumber,
		BankAccountName: accountName,
		DisbursementRef: ref,
		Timestamp:       timestamp,
		Signature:       sig,
	}

	body, _ := json.Marshal(payload)
	resp, err := http.Post(d.BaseURL+"/api/merchant/v2/disbursement", "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("duitku disbursement request: %w", err)
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	var result DuitkuDisbursementResponse
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, fmt.Errorf("duitku disbursement parse: %w", err)
	}
	if result.Status == "FAILED" {
		return nil, fmt.Errorf("disbursement failed: %s", result.Message)
	}
	return &result, nil
}
