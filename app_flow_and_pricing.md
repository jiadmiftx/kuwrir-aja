# KUWRIR App Flow & Financial Logic (MVP COD Model)

This document details the order lifecycle, cash handling procedures, and financial settlement logic for the MVP phase. **Note: For the initial launch, the platform operates exclusively on Cash on Delivery (COD).** Digital payments (Xendit, Duitku) will be introduced in a future update.

---

## 1. Configurable System Parameters (Admin Panel)

The backend will maintain a `system_settings` configuration store managed via the Admin Panel. 

| Setting Key | Description | Current Value / Formula |
| :--- | :--- | :--- |
| `food_markup_percentage` | Markup added to the restaurant's base price. **This cost is passed to the customer.** | `15%` |
| `delivery_commission_percentage` | The percentage of the delivery fee that KUWRIR retains. | `25%` (Configurable) |
| `delivery_base_fee_inside_zone` | Fixed delivery fee for customers inside the designated zone. | `IDR 15,000` |
| `delivery_fee_per_km_outside` | Additional fee per kilometer for deliveries outside the zone. | `IDR 10,000` / km |

---

## 2. Financial Calculation Example

### Scenario: Customer orders inside the zone

*   **Order Details:** 1x Ayam Bakar (Restaurant Base Price: IDR 50,000)
*   **Customer App Display & Payment:**
    *   Food Price Displayed: `IDR 50,000 + (15% markup)` = **IDR 57,500**
    *   Delivery Fee: **IDR 15,000**
    *   **Total Customer Pays (in Cash to Driver): IDR 72,500**

### How the Revenue is Split (Calculated by Admin/Backend)

From the **IDR 72,500** collected in cash:
*   **Restaurant Share:** IDR 50,000 (Their base price)
*   **Driver Share:** IDR 11,250 (75% of the 15k Delivery Fee)
*   **KUWRIR Revenue:** IDR 7,500 (15% Food Markup) + IDR 3,750 (25% of Delivery Fee) = **IDR 11,250**

---

## 3. Order Lifecycle & Cash Handling Flow

Because the MVP relies entirely on Cash on Delivery, the flow relies heavily on the Driver acting as the cash collector, followed by manual deposits to the Admin.

### Stage 1: Order Placement (Customer App)
1.  **Browse:** Customer sees menu prices with the 15% `food_markup_percentage` already applied.
2.  **Checkout:** Customer places the order. The app calculates the total (Marked-up Food + Delivery). Payment method is strictly **Cash**.

### Stage 2: Order Preparation (Restaurant App)
1.  **Notification:** Restaurant receives a push notification and in-app alert.
2.  **Acceptance & Prep:** Restaurant accepts and prepares the food.
3.  **Ready for Pickup:** Restaurant marks the order status as **"Ready to Pickup"** in the app.

### Stage 3: Driver Assignment & Delivery (Backend & Driver App)
1.  **Dispatch:** Backend assigns the order to an available driver.
2.  **Pickup:** Driver goes to the restaurant and picks up the food.
3.  **Delivery:** Driver navigates to the customer using Valhalla turn-by-turn routing.
4.  **Cash Collection:** Driver hands over the food and **collects the full cash amount** (e.g., IDR 72,500) from the customer. Driver marks the order as "Completed".

### Stage 4: Driver Deposit to Admin
1.  **Holding Cash:** The driver is now holding cash that belongs to the Restaurant, themselves, and KUWRIR.
2.  **Deposit Process:** At the end of their shift (or a designated period), the **Driver deposits the collected cash to the Admin** (via bank transfer to KUWRIR's account or physically at an office). 
3.  **App Tracking:** The Admin Panel must have a feature to track how much cash each driver owes the platform based on completed COD orders. Admin marks the driver's balance as "Cleared" once the deposit is received.

### Stage 5: Settlement to Restaurant (Admin Panel)
1.  **Monthly Calculation:** The Admin Panel tracks the total number of completed orders and the base food prices owed to each restaurant.
2.  **Payout:** Over a specific period (e.g., monthly or bi-weekly), the Admin calculates the total owed to Restaurant A. 
    *   *Note: Because the 15% markup was passed to the customer, the Admin simply pays the restaurant their original Base Price for all orders.*
3.  **Transfer:** Admin transfers the consolidated funds to the restaurant's bank account.

---

## 4. Admin Panel Required Features for MVP

To support this COD and manual settlement flow, the Admin Panel must include:

1.  **Driver Cash Ledger:** A dashboard showing how much cash each driver has collected from customers and currently owes the platform. Includes a "Settle/Clear Balance" button for when the driver deposits the cash.
2.  **Restaurant Settlement Reports:** A dashboard that aggregates total orders per restaurant over a selected date range (e.g., Month to Date) and calculates the exact payout amount owed (Sum of Base Food Prices). Includes a "Mark as Paid" workflow.
3.  **Configurable Fees Page:** The UI to adjust the `food_markup_percentage`, `delivery_commission_percentage`, and zone fees without requiring app store updates.
