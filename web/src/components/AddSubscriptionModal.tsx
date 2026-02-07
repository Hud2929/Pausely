import { useState } from 'react'
import { X, Loader2, DollarSign, Calendar, Globe, FileText } from 'lucide-react'
import { addSubscription } from '../lib/database'
import { SUBSCRIPTION_CATEGORIES, POPULAR_SERVICES } from '../types/subscription'
import type { SubscriptionCategory } from '../types/subscription'

interface AddSubscriptionModalProps {
  userId: string
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

export default function AddSubscriptionModal({ 
  userId, 
  isOpen, 
  onClose, 
  onSuccess 
}: AddSubscriptionModalProps) {
  const [name, setName] = useState('')
  const [amount, setAmount] = useState('')
  const [category, setCategory] = useState<SubscriptionCategory>('other')
  const [billingCycle, setBillingCycle] = useState<'monthly' | 'yearly' | 'weekly'>('monthly')
  const [renewalDate, setRenewalDate] = useState('')
  const [websiteUrl, setWebsiteUrl] = useState('')
  const [description, setDescription] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [showPopular, setShowPopular] = useState(true)

  const handleClose = () => {
    if (!loading) {
      onClose()
      // Reset form after close animation
      setTimeout(() => {
        setName('')
        setAmount('')
        setCategory('other')
        setBillingCycle('monthly')
        setRenewalDate('')
        setWebsiteUrl('')
        setDescription('')
        setError('')
        setShowPopular(true)
      }, 300)
    }
  }

  const handleSelectPopular = (serviceName: string) => {
    setName(serviceName)
    setShowPopular(false)
    
    // Auto-detect category based on service name
    const serviceCategories: Record<string, SubscriptionCategory> = {
      'Netflix': 'streaming',
      'Disney+': 'streaming',
      'Hulu': 'streaming',
      'Spotify': 'music',
      'Apple Music': 'music',
      'Xbox Game Pass': 'gaming',
      'PlayStation Plus': 'gaming',
      'Adobe Creative Cloud': 'software',
      'Figma': 'software',
      'Notion': 'software',
      'GitHub Pro': 'software',
      'Peloton': 'fitness',
      'Gym Membership': 'fitness',
      'Calm': 'fitness',
      'Headspace': 'fitness',
      'New York Times': 'news',
      'Medium': 'news',
      'LinkedIn Premium': 'news',
      'DoorDash DashPass': 'food',
      'Uber One': 'food'
    }
    
    if (serviceCategories[serviceName]) {
      setCategory(serviceCategories[serviceName])
    }
  }

  const validateForm = (): boolean => {
    if (!name.trim()) {
      setError('Please enter a subscription name')
      return false
    }
    if (!amount || parseFloat(amount) <= 0) {
      setError('Please enter a valid amount')
      return false
    }
    if (!category) {
      setError('Please select a category')
      return false
    }
    return true
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!validateForm()) return
    
    setLoading(true)
    setError('')

    try {
      const { data, error: submitError } = await addSubscription({
        user_id: userId,
        name: name.trim(),
        amount: parseFloat(amount),
        category,
        billing_cycle: billingCycle,
        renewal_date: renewalDate || null,
        website_url: websiteUrl || null,
        description: description || null,
        logo_url: null,
        status: 'active'
      })

      if (submitError) {
        setError('Failed to add subscription. Please try again.')
        setLoading(false)
        return
      }

      if (data) {
        onSuccess()
        handleClose()
      }
    } catch (err) {
      setError('An unexpected error occurred. Please try again.')
      setLoading(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/80 backdrop-blur-sm"
        onClick={handleClose}
      />

      {/* Modal */}
      <div className="relative w-full max-w-lg max-h-[90vh] overflow-y-auto bg-[#1a1a2e] rounded-3xl border border-white/10 shadow-2xl">
        {/* Header */}
        <div className="sticky top-0 bg-[#1a1a2e] border-b border-white/10 px-6 py-4 flex items-center justify-between z-10">
          <h2 className="text-xl font-semibold text-white">
            Add Subscription
          </h2>
          <button
            onClick={handleClose}
            disabled={loading}
            className="p-2 hover:bg-white/10 rounded-full transition-colors disabled:opacity-50"
          >
            <X className="w-5 h-5 text-white/60" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5">
          {/* Error Message */}
          {error && (
            <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              {error}
            </div>
          )}

          {/* Popular Services */}
          {showPopular && (
            <div>
              <label className="block text-sm font-medium text-white/70 mb-3">
                Popular Services
              </label>
              <div className="grid grid-cols-4 gap-2">
                {POPULAR_SERVICES.slice(0, 12).map((service) => (
                  <button
                    key={service}
                    type="button"
                    onClick={() => handleSelectPopular(service)}
                    className="p-3 rounded-xl bg-white/5 hover:bg-white/10 border border-white/5 hover:border-white/20 transition-all text-xs text-white/80 font-medium text-center"
                  >
                    {service}
                  </button>
                ))}
              </div>
              <button
                type="button"
                onClick={() => setShowPopular(false)}
                className="mt-3 text-sm text-blue-400 hover:text-blue-300"
              >
                Enter custom service →
              </button>
            </div>
          )}

          {/* Name */}
          <div>
            <label className="block text-sm font-medium text-white/70 mb-2">
              Service Name *
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., Netflix"
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder:text-white/30 focus:outline-none focus:border-blue-500/50 transition-colors"
              disabled={loading}
            />
          </div>

          {/* Amount & Billing Cycle */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-white/70 mb-2">
                Amount *
              </label>
              <div className="relative">
                <DollarSign className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-white/40" />
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="9.99"
                  className="w-full bg-white/5 border border-white/10 rounded-xl pl-12 pr-4 py-3 text-white placeholder:text-white/30 focus:outline-none focus:border-blue-500/50 transition-colors"
                  disabled={loading}
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-white/70 mb-2">
                Billing Cycle
              </label>
              <select
                value={billingCycle}
                onChange={(e) => setBillingCycle(e.target.value as 'monthly' | 'yearly' | 'weekly')}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-blue-500/50 transition-colors appearance-none cursor-pointer"
                disabled={loading}
              >
                <option value="monthly" className="bg-[#1a1a2e]">Monthly</option>
                <option value="yearly" className="bg-[#1a1a2e]">Yearly</option>
                <option value="weekly" className="bg-[#1a1a2e]">Weekly</option>
              </select>
            </div>
          </div>

          {/* Category */}
          <div>
            <label className="block text-sm font-medium text-white/70 mb-2">
              Category *
            </label>
            <div className="grid grid-cols-3 gap-2">
              {SUBSCRIPTION_CATEGORIES.map((cat) => (
                <button
                  key={cat.value}
                  type="button"
                  onClick={() => setCategory(cat.value)}
                  disabled={loading}
                  className={`p-3 rounded-xl border transition-all text-sm font-medium flex flex-col items-center gap-1 ${
                    category === cat.value
                      ? 'bg-blue-500/20 border-blue-500/50 text-blue-400'
                      : 'bg-white/5 border-white/10 text-white/60 hover:bg-white/10'
                  }`}
                >
                  <span className="text-lg">{cat.icon}</span>
                  <span>{cat.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Renewal Date */}
          <div>
            <label className="block text-sm font-medium text-white/70 mb-2 flex items-center gap-2">
              <Calendar className="w-4 h-4" />
              Next Renewal Date
            </label>
            <input
              type="date"
              value={renewalDate}
              onChange={(e) => setRenewalDate(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-blue-500/50 transition-colors"
              disabled={loading}
            />
          </div>

          {/* Website URL */}
          <div>
            <label className="block text-sm font-medium text-white/70 mb-2 flex items-center gap-2">
              <Globe className="w-4 h-4" />
              Website URL
            </label>
            <input
              type="url"
              value={websiteUrl}
              onChange={(e) => setWebsiteUrl(e.target.value)}
              placeholder="https://..."
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder:text-white/30 focus:outline-none focus:border-blue-500/50 transition-colors"
              disabled={loading}
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium text-white/70 mb-2 flex items-center gap-2">
              <FileText className="w-4 h-4" />
              Notes (Optional)
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Any notes about this subscription..."
              rows={3}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder:text-white/30 focus:outline-none focus:border-blue-500/50 transition-colors resize-none"
              disabled={loading}
            />
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            className="w-full bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold py-4 rounded-xl flex items-center justify-center gap-2 transition-all"
          >
            {loading ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                Adding...
              </>
            ) : (
              'Add Subscription'
            )}
          </button>
        </form>
      </div>
    </div>
  )
}
