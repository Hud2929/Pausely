import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { DollarSign, TrendingUp, PauseCircle, Gift } from 'lucide-react'

interface Subscription {
  id: string
  name: string
  amount: number
  billing_frequency: string
  status: string
  cost_per_hour: number | null
}

export default function Dashboard() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([])
  const [monthlySpend, setMonthlySpend] = useState(0)
  const [annualSpend, setAnnualSpend] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchSubscriptions()
  }, [])

  async function fetchSubscriptions() {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data, error } = await supabase
        .from('subscriptions')
        .select('*')
        .eq('user_id', user.id)
        .eq('status', 'active')

      if (error) throw error

      setSubscriptions(data || [])
      
      // Calculate totals
      let monthly = 0
      let annual = 0
      
      data?.forEach((sub: Subscription) => {
        if (sub.billing_frequency === 'monthly') {
          monthly += sub.amount
          annual += sub.amount * 12
        } else if (sub.billing_frequency === 'yearly') {
          annual += sub.amount
          monthly += sub.amount / 12
        }
      })
      
      setMonthlySpend(monthly)
      setAnnualSpend(annual)
    } catch (error) {
      console.error('Error:', error)
    } finally {
      setLoading(false)
    }
  }

  // Mock data for demo
  const hasData = subscriptions.length > 0
  const displayMonthly = hasData ? monthlySpend : 127.43
  const displayAnnual = hasData ? annualSpend : 1529.16

  if (loading) {
    return (
      <div className="flex justify-center items-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  return (
    <div className="max-w-md mx-auto px-4 py-6">
      <h1 className="text-2xl font-bold mb-6">Pausely</h1>
      
      {/* Total Spend Card */}
      <div className="bg-white rounded-2xl shadow-sm p-6 mb-6">
        <h2 className="text-gray-500 text-sm font-medium mb-4">Total Subscriptions</h2>
        <div className="flex gap-8">
          <div>
            <p className="text-gray-400 text-xs mb-1">Monthly</p>
            <p className="text-2xl font-bold">${displayMonthly.toFixed(2)}</p>
          </div>
          <div>
            <p className="text-gray-400 text-xs mb-1">Yearly</p>
            <p className="text-2xl font-bold">${displayAnnual.toFixed(2)}</p>
          </div>
        </div>
      </div>

      {/* Insights */}
      <div className="mb-6">
        <h2 className="text-lg font-semibold mb-3">Insights</h2>
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-white rounded-xl p-4 shadow-sm">
            <PauseCircle className="w-8 h-8 text-orange-500 mb-2" />
            <p className="font-semibold text-sm">Pause subscriptions</p>
            <p className="text-xs text-gray-500">Save $50/mo</p>
          </div>
          <div className="bg-white rounded-xl p-4 shadow-sm">
            <Gift className="w-8 h-8 text-green-500 mb-2" />
            <p className="font-semibold text-sm">3 free perks</p>
            <p className="text-xs text-gray-500">Not activated</p>
          </div>
        </div>
      </div>

      {/* Worst Value */}
      <div className="mb-6">
        <h2 className="text-lg font-semibold mb-3">Worst Value</h2>
        <p className="text-xs text-gray-500 mb-3">These cost the most per hour of use</p>
        
        {!hasData ? (
          <div className="bg-white rounded-xl p-4 shadow-sm text-center">
            <p className="text-gray-500 text-sm">Add subscriptions to see insights</p>
          </div>
        ) : (
          subscriptions
            .filter(s => s.cost_per_hour)
            .sort((a, b) => (b.cost_per_hour || 0) - (a.cost_per_hour || 0))
            .slice(0, 3)
            .map(sub => (
              <div key={sub.id} className="bg-white rounded-xl p-4 shadow-sm mb-3 flex items-center gap-3">
                <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center text-lg font-bold">
                  {sub.name[0]}
                </div>
                <div className="flex-1">
                  <p className="font-semibold">{sub.name}</p>
                  <p className="text-xs text-red-500">
                    ${sub.cost_per_hour?.toFixed(2)}/hour
                  </p>
                </div>
                <p className="font-semibold text-gray-600">${sub.amount}</p>
              </div>
            ))
        )}
      </div>

      {/* Demo Data Notice */}
      {!hasData && (
        <div className="bg-blue-50 rounded-xl p-4 border border-blue-200">
          <p className="text-sm text-blue-800">
            <strong>Demo Mode:</strong> Showing sample data. Add your Supabase credentials to see your real subscriptions.
          </p>
        </div>
      )}
    </div>
  )
}
