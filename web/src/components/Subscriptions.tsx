import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { Plus } from 'lucide-react'

interface Subscription {
  id: string
  name: string
  description: string | null
  amount: number
  currency: string
  billing_frequency: string
  status: string
  can_pause: boolean
  next_billing_date: string | null
}

export default function Subscriptions() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([])
  const [showAddModal, setShowAddModal] = useState(false)
  const [newSub, setNewSub] = useState({
    name: '',
    amount: '',
    frequency: 'monthly'
  })

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
        .order('amount', { ascending: false })

      if (error) throw error
      setSubscriptions(data || [])
    } catch (error) {
      console.error('Error:', error)
    }
  }

  async function addSubscription(e: React.FormEvent) {
    e.preventDefault()
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { error } = await supabase.from('subscriptions').insert([{
        user_id: user.id,
        name: newSub.name,
        amount: parseFloat(newSub.amount),
        billing_frequency: newSub.frequency,
        currency: 'USD',
        status: 'active',
        is_detected: false
      }])

      if (error) throw error

      setShowAddModal(false)
      setNewSub({ name: '', amount: '', frequency: 'monthly' })
      fetchSubscriptions()
    } catch (error) {
      console.error('Error adding subscription:', error)
      alert('Error adding subscription. Check console.')
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active': return 'bg-green-100 text-green-700'
      case 'paused': return 'bg-yellow-100 text-yellow-700'
      case 'cancelled': return 'bg-red-100 text-red-700'
      default: return 'bg-gray-100 text-gray-700'
    }
  }

  return (
    <div className="max-w-md mx-auto px-4 py-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Subscriptions</h1>
        <button
          onClick={() => setShowAddModal(true)}
          className="bg-blue-600 text-white p-2 rounded-full"
        >
          <Plus size={20} />
        </button>
      </div>

      {subscriptions.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500 mb-4">No subscriptions yet</p>
          <button
            onClick={() => setShowAddModal(true)}
            className="bg-blue-600 text-white px-6 py-3 rounded-xl font-medium"
          >
            Add Your First Subscription
          </button>
        </div>
      ) : (
        <div className="space-y-3">
          {subscriptions.map(sub => (
            <div key={sub.id} className="bg-white rounded-xl p-4 shadow-sm">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center text-lg font-bold">
                  {sub.name[0]}
                </div>
                
                <div className="flex-1">
                  <p className="font-semibold">{sub.name}</p>
                  <div className="flex items-center gap-2 mt-1">
                    <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(sub.status)}`}>
                      {sub.status}
                    </span>
                    {sub.can_pause && (
                      <span className="text-xs text-orange-600">Can pause</span>
                    )}
                  </div>
                  {sub.next_billing_date && (
                    <p className="text-xs text-gray-500 mt-1">
                      Next: {new Date(sub.next_billing_date).toLocaleDateString()}
                    </p>
                  )}
                </div>
                
                <div className="text-right">
                  <p className="font-bold">${sub.amount}</p>
                  <p className="text-xs text-gray-500">/{sub.billing_frequency}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl p-6 w-full max-w-sm">
            <h2 className="text-xl font-bold mb-4">Add Subscription</h2>
            
            <form onSubmit={addSubscription}>
              <div className="mb-4">
                <label className="block text-sm font-medium mb-1">Name</label>
                <input
                  type="text"
                  value={newSub.name}
                  onChange={e => setNewSub({...newSub, name: e.target.value})}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2"
                  placeholder="Netflix, Spotify, etc."
                  required
                />
              </div>
              
              <div className="mb-4">
                <label className="block text-sm font-medium mb-1">Amount</label>
                <input
                  type="number"
                  step="0.01"
                  value={newSub.amount}
                  onChange={e => setNewSub({...newSub, amount: e.target.value})}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2"
                  placeholder="15.99"
                  required
                />
              </div>
              
              <div className="mb-6">
                <label className="block text-sm font-medium mb-1">Billing Frequency</label>
                <select
                  value={newSub.frequency}
                  onChange={e => setNewSub({...newSub, frequency: e.target.value})}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2"
                >
                  <option value="monthly">Monthly</option>
                  <option value="yearly">Yearly</option>
                  <option value="weekly">Weekly</option>
                </select>
              </div>
              
              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="flex-1 py-3 border border-gray-300 rounded-xl font-medium"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-3 bg-blue-600 text-white rounded-xl font-medium"
                >
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
