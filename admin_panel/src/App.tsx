import { BrowserRouter, Routes, Route } from 'react-router-dom'
import AdminLayout from '@/components/layout/AdminLayout'
import DashboardPage from '@/pages/DashboardPage'
import LoginPage from '@/pages/LoginPage'
import SettingsPage from '@/pages/SettingsPage'
import MerchantsPage from '@/pages/MerchantsPage'
import OrdersPage from '@/pages/OrdersPage'
import DriversPage from '@/pages/DriversPage'
import DriverApplicationsPage from '@/pages/DriverApplicationsPage'
import CustomersPage from '@/pages/CustomersPage'
import PromotionsPage from '@/pages/PromotionsPage'
import FoodCategoriesPage from '@/pages/FoodCategoriesPage'
import BannersPage from '@/pages/BannersPage'
import WhatsAppPage from '@/pages/WhatsAppPage'
import SettlementsPage from '@/pages/SettlementsPage'
import RevenuePage from '@/pages/RevenuePage'
import SupportChatsPage from '@/pages/SupportChatsPage'
import DeliveryZonesPage from '@/pages/DeliveryZonesPage'

export default function App() {
  return (
    <BrowserRouter>
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
                <Route path="/merchants" element={<MerchantsPage />} />
                <Route path="/drivers" element={<DriversPage />} />
                <Route path="/driver-applications" element={<DriverApplicationsPage />} />
                <Route path="/customers" element={<CustomersPage />} />
                <Route path="/promos" element={<PromotionsPage />} />
                <Route path="/food-categories" element={<FoodCategoriesPage />} />
                <Route path="/banners" element={<BannersPage />} />
                <Route path="/whatsapp" element={<WhatsAppPage />} />
                <Route path="/settlements" element={<SettlementsPage />} />
                <Route path="/revenue" element={<RevenuePage />} />
                <Route path="/support" element={<SupportChatsPage />} />
                <Route path="/delivery-zones" element={<DeliveryZonesPage />} />
              </Routes>
            </AdminLayout>
          }
        />
      </Routes>
    </BrowserRouter>
  )
}

