import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Tag } from 'lucide-react'

export default function PromotionsPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Promotions</h2>
          <p className="text-muted-foreground">Manage discount vouchers and promos</p>
        </div>
        <Button>
          <Tag className="mr-2 h-4 w-4" /> Create Promo
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Active Promotions</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-10 text-muted-foreground">
            <Tag className="mx-auto h-12 w-12 opacity-20 mb-4" />
            <p>No active promotions.</p>
            <p className="text-sm">Promotions feature will be fully implemented in a future update.</p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
