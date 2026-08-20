import { apiFetch } from "@/lib/api/client";
import type {
  Address,
  AppNotification,
  AuthResponse,
  Banner,
  ChatMessage,
  FoodCategory,
  Merchant,
  Order,
  OrderItem,
  OrderModificationRequest,
  PaymentMethod,
  PlaceOrderRequest,
  ProductCategory,
  ProductSearchItem,
  QuoteRequest,
  QuoteResponse,
  RefundRequest,
  SupportMessage,
  User,
  Wallet,
  WalletTransaction,
} from "@/lib/api/types";

// --- Auth ---
export const requestOtp = (phone: string) =>
  apiFetch<{ message?: string }>("/auth/otp/request", { method: "POST", body: { phone }, skipAuth: true });

export const verifyOtp = (phone: string, code: string, agreeTerms: boolean) =>
  apiFetch<AuthResponse>("/auth/otp/verify", {
    method: "POST",
    body: { phone, code, agree_terms: agreeTerms },
    skipAuth: true,
  });

export const getMe = () => apiFetch<{ user: User }>("/auth/me");
export const updateMe = (body: Partial<Pick<User, "name" | "email">>) =>
  apiFetch<{ user: User }>("/auth/me", { method: "PUT", body });
export const saveDeviceToken = (token: string) =>
  apiFetch<{ message?: string }>("/auth/device-token", { method: "PUT", body: { token } });

// --- Browse ---
export const getActiveBanners = () => apiFetch<{ banners: Banner[] }>("/banners/active", { skipAuth: true });
export const getFoodCategories = () =>
  apiFetch<{ food_categories: FoodCategory[] }>("/food-categories", { skipAuth: true });
export const getPopularMerchants = (foodCategoryId?: string) =>
  apiFetch<{ merchants: Merchant[] }>("/merchants/popular", {
    skipAuth: true,
    query: { food_category_id: foodCategoryId },
  });
export const getNearbyMerchants = (lat: number, lng: number, radiusKm = 10, foodCategoryId?: string) =>
  apiFetch<{ merchants: Merchant[] }>("/merchants/nearby", {
    skipAuth: true,
    query: { lat, lng, radius: radiusKm, food_category_id: foodCategoryId },
  });
export const searchMerchants = (q: string) =>
  apiFetch<{ merchants: Merchant[] }>("/merchants/search", { skipAuth: true, query: { q } });
export const searchProducts = (params: {
  q?: string;
  food_category_id?: string;
  discount?: boolean;
  free_delivery?: boolean;
}) =>
  apiFetch<{ products: ProductSearchItem[] }>("/products/search", {
    skipAuth: true,
    query: {
      q: params.q,
      food_category_id: params.food_category_id,
      discount: params.discount ? "true" : undefined,
      free_delivery: params.free_delivery ? "true" : undefined,
    },
  });
export const getPopularProducts = () =>
  apiFetch<{ products: ProductSearchItem[] }>("/products/popular", { skipAuth: true });
export const getMerchant = (id: string) => apiFetch<{ merchant: Merchant }>(`/merchants/${id}`, { skipAuth: true });
export const getMerchantProducts = (id: string) =>
  apiFetch<{ categories: ProductCategory[] }>(`/merchants/${id}/products`, { skipAuth: true });

// --- Addresses ---
export const getAddresses = () => apiFetch<{ addresses: Address[] }>("/addresses");
export const createAddress = (body: Omit<Address, "id" | "user_id">) =>
  apiFetch<{ address: Address }>("/addresses", { method: "POST", body });
export const updateAddress = (id: string, body: Omit<Address, "id" | "user_id">) =>
  apiFetch<{ address: Address }>(`/addresses/${id}`, { method: "PUT", body });
export const deleteAddress = (id: string) => apiFetch<void>(`/addresses/${id}`, { method: "DELETE" });
export const setDefaultAddress = (id: string) =>
  apiFetch<{ address: Address }>(`/addresses/${id}/default`, { method: "PUT" });

// --- Orders ---
export const quoteOrder = (body: QuoteRequest) =>
  apiFetch<QuoteResponse>("/orders/quote", { method: "POST", body });
export const placeOrder = (body: PlaceOrderRequest) =>
  apiFetch<{ order: Order }>("/orders", { method: "POST", body });
export const getMyOrders = () => apiFetch<{ orders: Order[] }>("/orders");
export const getOrder = (id: string) => apiFetch<{ order: Order; has_review: boolean }>(`/orders/${id}`);
export const submitOrderReview = (
  orderId: string,
  body: { merchant_rating?: number; driver_rating?: number; comment?: string }
) => apiFetch<{ message: string }>(`/orders/${orderId}/review`, { method: "POST", body });
export const cancelOrder = (id: string) => apiFetch<{ order: Order }>(`/orders/${id}/cancel`, { method: "POST" });
export const getOrderChat = (id: string) => apiFetch<{ messages: ChatMessage[] }>(`/orders/${id}/chat`);
export const sendOrderChat = (id: string, text: string) =>
  apiFetch<{ message: ChatMessage }>(`/orders/${id}/chat`, { method: "POST", body: { text } });
export const requestRefund = (orderId: string, reason: string) =>
  apiFetch<{ refund: RefundRequest; message: string }>(`/orders/${orderId}/refund-request`, {
    method: "POST",
    body: { reason },
  });

// Merchant flagged an item unavailable on an already-accepted order —
// customer picks a replacement from the live menu or cancels. See
// backend RequestItemChange/ResolveModificationRequest.
export const getModificationRequest = (orderId: string) =>
  apiFetch<{ modification_request: OrderModificationRequest; removed_item: OrderItem }>(
    `/orders/${orderId}/modification-request`
  );
export const replaceOrderItem = (
  orderId: string,
  requestId: string,
  body: { product_id: string; quantity: number; variant_ids: string[] }
) =>
  apiFetch<{ order: Order; topup_payment_url?: string }>(`/orders/${orderId}/modification-request/${requestId}/resolve`, {
    method: "POST",
    body: { action: "replace", ...body },
  });
export const cancelViaModificationRequest = (orderId: string, requestId: string) =>
  apiFetch<{ order: Order; status: string }>(`/orders/${orderId}/modification-request/${requestId}/resolve`, {
    method: "POST",
    body: { action: "cancel" },
  });

// --- Payment ---
export const getPaymentMethods = (amount: number) =>
  apiFetch<{ payment_methods: PaymentMethod[] }>("/payment/methods", { query: { amount } });
export const createPayment = (orderId: string, paymentMethod: string, email?: string) =>
  apiFetch<{ payment_url: string; payment_ref: string; amount: number; expires_at: string }>(
    `/payment/${orderId}/create`,
    { method: "POST", body: { payment_method: paymentMethod, email } }
  );

// --- Support ---
export const getSupportMessages = () => apiFetch<{ messages: SupportMessage[] }>("/support/messages");
export const sendSupportMessage = (text: string) =>
  apiFetch<{ message: SupportMessage }>("/support/messages", { method: "POST", body: { text } });

// --- Notifications ---
// Server-persisted history of every push service.SendToUser has sent this
// user (see backend/internal/handler/notification) — unlike customer_app's
// on-device SharedPreferences cache, this survives across browsers/devices
// and doesn't depend on the push having actually been delivered locally.
export const getMyNotifications = () => apiFetch<{ notifications: AppNotification[] }>("/me/notifications");
export const markNotificationRead = (id: string) =>
  apiFetch<{ message: string }>(`/me/notifications/${id}/read`, { method: "POST" });

// --- Wallet ---
export const getWallet = () => apiFetch<{ wallet: Wallet }>("/customer/wallet");
export const getWalletTransactions = () =>
  apiFetch<{ wallet: Wallet; transactions: WalletTransaction[] }>("/customer/wallet/transactions");
export const topupWallet = (amount: number, paymentMethod: string, email?: string) =>
  apiFetch<{ payment_url: string; payment_ref: string; amount: number; expires_at: string }>(
    "/customer/wallet/topup",
    { method: "POST", body: { amount, payment_method: paymentMethod, email } }
  );
export const withdrawWallet = (body: {
  amount: number;
  bank_code: string;
  bank_account_number: string;
  bank_account_name: string;
}) =>
  apiFetch<{ message: string; disbursement_ref: string; status: string; amount: number }>(
    "/customer/wallet/withdraw",
    { method: "POST", body }
  );

// --- Legal ---
export const getCustomerTerms = () =>
  apiFetch<{ content: string; version: string }>("/legal/customer-terms", { skipAuth: true });
