import { BrowserRouter, Routes, Route } from 'react-router-dom'
import AdminLayout from '@/components/layout/AdminLayout'
import DashboardPage from '@/pages/DashboardPage'
import LoginPage from '@/pages/LoginPage'
import SettingsPage from '@/pages/SettingsPage'
import MerchantsPage from '@/pages/MerchantsPage'
import MerchantDetailPage from '@/pages/MerchantDetailPage'
import OrdersPage from '@/pages/OrdersPage'
import OrderDetailPage from '@/pages/OrderDetailPage'
import DriversPage from '@/pages/DriversPage'
import DriverDetailPage from '@/pages/DriverDetailPage'
import DriverApplicationsPage from '@/pages/DriverApplicationsPage'
import CustomersPage from '@/pages/CustomersPage'
import CustomerDetailPage from '@/pages/CustomerDetailPage'
import PromotionsPage from '@/pages/PromotionsPage'
import FoodCategoriesPage from '@/pages/FoodCategoriesPage'
import BannersPage from '@/pages/BannersPage'
import WhatsAppPage from '@/pages/WhatsAppPage'
import SettlementsPage from '@/pages/SettlementsPage'
import WithdrawalsPage from '@/pages/WithdrawalsPage'
import RevenuePage from '@/pages/RevenuePage'
import SupportChatsPage from '@/pages/SupportChatsPage'
import DeliveryZonesPage from '@/pages/DeliveryZonesPage'
import UsersPage from '@/pages/UsersPage'
import AuditLogPage from '@/pages/AuditLogPage'
import { Toaster } from '@/components/ui/sonner'

export default function App() {
  return (
    <BrowserRouter>
      {/* Mounted once here so every page's toast.success/toast.error calls
          (sonner) actually render somewhere — without this, every toast()
          call across the whole admin panel is a silent no-op. */}
      <Toaster richColors position="top-right" />
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/*"
          element={
            <AdminLayout>
              <Routes>
                <Route path="/" element={<DashboardPage />} />
                <Route path="/settings" element={<SettingsPage />} />
                <Route path="/orders" element={<OrdersPage />} />
                <Route path="/orders/:id" element={<OrderDetailPage />} />
                <Route path="/merchants" element={<MerchantsPage />} />
                <Route path="/merchants/:id" element={<MerchantDetailPage />} />
                <Route path="/drivers" element={<DriversPage />} />
                <Route path="/drivers/:id" element={<DriverDetailPage />} />
                <Route path="/driver-applications" element={<DriverApplicationsPage />} />
                <Route path="/customers" element={<CustomersPage />} />
                <Route path="/customers/:id" element={<CustomerDetailPage />} />
                <Route path="/promos" element={<PromotionsPage />} />
                <Route path="/food-categories" element={<FoodCategoriesPage />} />
                <Route path="/banners" element={<BannersPage />} />
                <Route path="/whatsapp" element={<WhatsAppPage />} />
                <Route path="/settlements" element={<SettlementsPage />} />
                <Route path="/withdrawals" element={<WithdrawalsPage />} />
                <Route path="/revenue" element={<RevenuePage />} />
                <Route path="/support" element={<SupportChatsPage />} />
                <Route path="/delivery-zones" element={<DeliveryZonesPage />} />
                <Route path="/admins" element={<UsersPage />} />
                <Route path="/audit-logs" element={<AuditLogPage />} />
              </Routes>
            </AdminLayout>
          }
        />
      </Routes>
    </BrowserRouter>
  )
}

