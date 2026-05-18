import { type ReactNode } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
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
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Separator } from '@/components/ui/separator'

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/orders', icon: ShoppingBag, label: 'Orders' },
  { to: '/merchants', icon: Store, label: 'Merchants' },
  { to: '/drivers', icon: Bike, label: 'Drivers' },
  { to: '/customers', icon: Users, label: 'Customers' },
  { to: '/promos', icon: Tag, label: 'Promotions' },
  { to: '/settlements', icon: Banknote, label: 'Settlements' },
  { to: '/settings', icon: Settings, label: 'Settings' },
]

export default function AdminLayout({ children }: { children: ReactNode }) {
  const navigate = useNavigate()

  return (
    <div className="flex h-screen bg-background">
      {/* Sidebar */}
      <aside className="hidden w-64 flex-col border-r bg-sidebar lg:flex">
        {/* Logo */}
        <div className="flex h-16 items-center gap-2 px-6">
          <span className="text-2xl">📦</span>
          <h1 className="text-xl font-bold text-sidebar-foreground">KUWRIR</h1>
          <span className="ml-auto rounded bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary">
            Admin
          </span>
        </div>

        <Separator />

        {/* Navigation */}
        <nav className="flex-1 space-y-1 px-3 py-4">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
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

        <Separator />

        {/* Logout */}
        <div className="p-3">
          <Button
            variant="ghost"
            className="w-full justify-start gap-3 text-muted-foreground"
            onClick={() => navigate('/login')}
          >
            <LogOut className="h-4 w-4" />
            Logout
          </Button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <div className="p-6 lg:p-8">{children}</div>
      </main>
    </div>
  )
}
