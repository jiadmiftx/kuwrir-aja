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
import SettlementsPage from '@/pages/SettlementsPage'
import RevenuePage from '@/pages/RevenuePage'
import SupportChatsPage from '@/pages/SupportChatsPage'
import ZonesMapPage from '@/pages/ZonesMapPage'

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
                <Route path="/settlements" element={<SettlementsPage />} />
                <Route path="/revenue" element={<RevenuePage />} />
                <Route path="/support" element={<SupportChatsPage />} />
                <Route path="/zones-map" element={<ZonesMapPage />} />
              </Routes>
            </AdminLayout>
          }
        />
      </Routes>
    </BrowserRouter>
  )
}

