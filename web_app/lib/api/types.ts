// Mirrors backend/internal/model JSON shapes. Only fields the web app
// actually reads/writes are included.

export interface User {
  id: string;
  name: string;
  email: string;
  phone: string;
  avatar_url?: string;
  role: string;
  is_active: boolean;
}

export interface AuthResponse {
  token: string;
  refresh_token: string;
  user: User;
}

export interface Address {
  id: string;
  user_id: string;
  label: string;
  address: string;
  detail: string;
  latitude: number;
  longitude: number;
  is_default: boolean;
}

export interface FoodCategory {
  id: string;
  name: string;
  icon?: string;
  sort_order: number;
  is_active: boolean;
}

export interface Banner {
  id: string;
  image_url?: string;
  title: string;
  subtitle?: string;
  cta_text: string;
  food_category_id?: string;
  promo_type?: string;
}

export interface Merchant {
  id: string;
  name: string;
  slug: string;
  description?: string;
  phone: string;
  logo_url?: string;
  banner_url?: string;
  address: string;
  latitude: number;
  longitude: number;
  rating: number;
  total_reviews: number;
  is_active: boolean;
  is_verified: boolean;
  is_open: boolean;
  can_self_deliver: boolean;
  is_free_delivery: boolean;
  distance_km?: number;
}

export interface ProductVariant {
  id: string;
  product_id: string;
  group_name: string;
  name: string;
  price: number;
  is_required: boolean;
  min_select: number;
  max_select: number;
}

export interface Product {
  id: string;
  category_id: string;
  food_category_id?: string;
  name: string;
  description?: string;
  price: number;
  discount_price?: number;
  price_unit: string;
  image_url?: string;
  is_available: boolean;
  track_stock: boolean;
  stock_quantity: number;
  packaging_fee: number;
  variants?: ProductVariant[];
}

export interface ProductSearchItem extends Product {
  merchant_id: string;
  merchant_name: string;
  merchant_logo_url?: string;
  merchant_is_open: boolean;
}

export interface ProductCategory {
  id: string;
  merchant_id: string;
  name: string;
  sort_order: number;
  products: Product[];
}

export interface OrderItemRequest {
  product_id: string;
  quantity: number;
  notes: string;
  variant_ids: string[];
}

export interface QuoteRequest {
  merchant_id: string;
  items: OrderItemRequest[];
  dropoff_lat: number;
  dropoff_lng: number;
  payment_type: string;
  promo_code: string;
}

export interface QuoteResponse {
  subtotal: number;
  packaging_fee: number;
  delivery_fee: number;
  delivery_type: string;
  app_service_fee: number;
  tax_amount: number;
  discount_amount: number;
  total: number;
  distance_km: number;
}

export interface PlaceOrderRequest {
  merchant_id: string;
  items: OrderItemRequest[];
  dropoff_address: string;
  dropoff_lat: number;
  dropoff_lng: number;
  receiver_name: string;
  receiver_phone: string;
  payment_type: string;
  notes: string;
  promo_code: string;
}

export interface OrderItem {
  id: string;
  order_id: string;
  product_id?: string;
  item_name: string;
  quantity: number;
  unit_price: number;
  total_price: number;
  variants_json?: string;
  notes?: string;
}

export interface Order {
  id: string;
  order_number: string;
  service_type: string;
  status: string;
  delivery_type: string;
  payment_type: string;
  subtotal: number;
  delivery_fee: number;
  tax_amount: number;
  app_service_fee: number;
  packaging_fee: number;
  discount_amount: number;
  total: number;
  pickup_address?: string;
  dropoff_address?: string;
  distance_km: number;
  notes?: string;
  promo_code?: string;
  payment_status: string;
  payment_url?: string;
  payment_ref?: string;
  payment_expired_at?: string;
  placed_at?: string;
  confirmed_at?: string;
  ready_at?: string;
  accepted_at?: string;
  picked_up_at?: string;
  delivered_at?: string;
  cancelled_at?: string;
  created_at: string;
  merchant?: Merchant;
  items?: OrderItem[];
}

export interface ChatMessage {
  id: string;
  order_id: string;
  sender_id: string;
  sender_role: string;
  text: string;
  created_at: string;
}

// Passed straight through from Duitku's own API response by the backend
// (internal/service/duitku.go DuitkuPaymentMethod) — camelCase, unlike the
// rest of this backend's snake_case JSON.
export interface PaymentMethod {
  paymentMethod: string; // e.g. "VC", "QRIS", "OV"
  paymentName: string;
  paymentImage?: string;
  totalFee?: string;
}

export interface SupportMessage {
  id: string;
  user_id: string;
  sender_role: string; // customer | admin
  text: string;
  is_read: boolean;
  created_at: string;
}

export interface Wallet {
  id: string;
  user_id: string;
  balance: number;
  total_earned: number;
  total_withdrawn: number;
}

export interface WalletTransaction {
  id: string;
  wallet_id: string;
  order_id?: string;
  type: "credit" | "debit";
  category: string;
  amount: number;
  balance_after: number;
  notes?: string;
  created_at: string;
}

export interface RefundRequest {
  id: string;
  order_id: string;
  reason: string;
  amount: number;
  status: string;
  admin_note?: string;
}
