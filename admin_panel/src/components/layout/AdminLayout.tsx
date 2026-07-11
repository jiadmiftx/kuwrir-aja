import { type ReactNode, useEffect, useState } from 'react'
import { NavLink, useLocation, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard,
  Store,
  Users,
  Bike,
  ShoppingBag,
  Settings,
  LogOut,
  Tag,
  Banknote,
  ClipboardList,
  TrendingUp,
  MessageSquare,
  Map,
  UtensilsCrossed,
  Image,
  MessageCircle,
  Wallet,
  ShieldCheck,
  History,
  Menu,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Separator } from '@/components/ui/separator'
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet'

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/orders', icon: ShoppingBag, label: 'Orders' },
  { to: '/merchants', icon: Store, label: 'Merchants' },
  { to: '/drivers', icon: Bike, label: 'Drivers' },
  { to: '/driver-applications', icon: ClipboardList, label: 'Driver Applications' },
  { to: '/customers', icon: Users, label: 'Customers' },
  { to: '/promos', icon: Tag, label: 'Promotions' },
  { to: '/food-categories', icon: UtensilsCrossed, label: 'Food Categories' },
  { to: '/banners', icon: Image, label: 'Banners' },
  { to: '/settlements', icon: Banknote, label: 'Settlements' },
  { to: '/withdrawals', icon: Wallet, label: 'Withdrawals' },
  { to: '/revenue', icon: TrendingUp, label: 'Revenue' },
  { to: '/support', icon: MessageSquare, label: 'Support Chat' },
  { to: '/whatsapp', icon: MessageCircle, label: 'WhatsApp Gateway' },
  { to: '/delivery-zones', icon: Map, label: 'Delivery Zones' },
  // Superadmin-only: managing who else has admin access.
  { to: '/admins', icon: ShieldCheck, label: 'Admin Users', superadminOnly: true },
  { to: '/audit-logs', icon: History, label: 'Audit Log' },
  { to: '/settings', icon: Settings, label: 'Settings' },
]

function currentAdminTier(): string {
  try {
    const raw = localStorage.getItem('user')
    if (!raw) return ''
    return JSON.parse(raw).admin_tier ?? ''
  } catch {
    return ''
  }
}

function visibleNavItems() {
  return navItems.filter((item) => {
    if (!item.superadminOnly) return true
    const tier = currentAdminTier()
    // Empty tier = a legacy admin account predating tiers, treated
    // as superadmin — mirrors the backend's SuperadminOnlyMiddleware.
    return tier === '' || tier === 'superadmin'
  })
}

// Shared between the desktop sidebar and the mobile drawer so both stay in
// sync — onNavigate lets the mobile drawer close itself after a link tap.
function NavList({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <nav className="flex-1 space-y-1 px-3 py-4">
      {visibleNavItems().map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          end={item.to === '/'}
          onClick={onNavigate}
          className={({ isActive }) =>
            `flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
              isActive
                ? 'bg-sidebar-accent text-sidebar-primary'
                : 'text-sidebar-foreground/70 hover:bg-sidebar-accent hover:text-sidebar-foreground'
            }`
          }
        >
          <item.icon className="h-4 w-4" />
          {item.label}
        </NavLink>
      ))}
    </nav>
  )
}

export default function AdminLayout({ children }: { children: ReactNode }) {
  const navigate = useNavigate()
  const location = useLocation()
  const [mobileNavOpen, setMobileNavOpen] = useState(false)

  useEffect(() => {
    if (!localStorage.getItem('token')) {
      navigate('/login', { replace: true })
    }
  }, [navigate])

  // Close the drawer automatically whenever the route changes (covers
  // back/forward nav too, not just link taps inside the drawer itself).
  useEffect(() => {
    setMobileNavOpen(false)
  }, [location.pathname])

  const logout = () => {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    navigate('/login')
  }

  return (
    <div className="flex h-screen flex-col bg-background lg:flex-row">
      {/* Mobile top bar: hamburger + logo, shown below the lg breakpoint
          where the sidebar is hidden entirely. */}
      <header className="flex h-14 shrink-0 items-center gap-3 border-b bg-sidebar px-4 lg:hidden">
        <Sheet open={mobileNavOpen} onOpenChange={setMobileNavOpen}>
          <SheetTrigger render={<Button variant="ghost" size="icon" />}>
            <Menu className="h-5 w-5" />
            <span className="sr-only">Buka menu</span>
          </SheetTrigger>
          <SheetContent side="left" className="w-72 gap-0 p-0">
            <div className="flex h-14 items-center gap-2 px-4">
              <img src="/logo_cocourir.svg" alt="Cocourir" className="h-7 w-auto object-contain" />
              <span className="ml-auto rounded bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary">
                Admin
              </span>
            </div>
            <Separator />
            <NavList onNavigate={() => setMobileNavOpen(false)} />
            <Separator />
            <div className="p-3">
              <Button
                variant="ghost"
                className="w-full justify-start gap-3 text-muted-foreground"
                onClick={logout}
              >
                <LogOut className="h-4 w-4" />
                Logout
              </Button>
            </div>
          </SheetContent>
        </Sheet>
        <img src="/logo_cocourir.svg" alt="Cocourir" className="h-6 w-auto object-contain" />
        <span className="ml-auto rounded bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary">
          Admin
        </span>
      </header>

      {/* Desktop sidebar */}
      <aside className="hidden w-64 flex-col border-r bg-sidebar lg:flex">
        <div className="flex h-16 items-center gap-2 px-6">
          <img src="/logo_cocourir.svg" alt="Cocourir" className="h-8 w-auto object-contain" />
          <span className="ml-auto rounded bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary">
            Admin
          </span>
        </div>

        <Separator />

        <NavList />

        <Separator />

        <div className="p-3">
          <Button
            variant="ghost"
            className="w-full justify-start gap-3 text-muted-foreground"
            onClick={logout}
          >
            <LogOut className="h-4 w-4" />
            Logout
          </Button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <div className="p-4 sm:p-6 lg:p-8">{children}</div>
      </main>
    </div>
  )
}
