import { useState } from 'react'
import { X, DollarSign, Calendar, Tag, ChevronDown, Loader2 } from 'lucide-react'
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
  const [step, setStep] = useState(1)
  const [name, setName] = useState('')
  const [amount, setAmount] = useState('')
  const [category, setCategory] = useState<SubscriptionCategory>('other')
  const [billingCycle, setBillingCycle] = useState<'monthly' | 'yearly' | 'weekly'>('monthly')
  const [renewalDate, setRenewalDate] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleClose = () => {
    if (!loading) {
      onClose()
      setTimeout(() => {
        setStep(1)
        setName('')
        setAmount('')
        setCategory('other')
        setBillingCycle('monthly')
        setRenewalDate('')
        setError('')
      }, 300)
    }
  }

  const handleSelectPopular = (serviceName: string) => {
    setName(serviceName)
    const lowerName = serviceName.toLowerCase()
    if (lowerName.includes('netflix') || lowerName.includes('hulu') || lowerName.includes('disney')) {
      setCategory('streaming')
    } else if (lowerName.includes('spotify') || lowerName.includes('apple music') || lowerName.includes('youtube')) {
      setCategory('music')
    } else if (lowerName.includes('gym') || lowerName.includes('fitness') || lowerName.includes('peloton')) {
      setCategory('fitness')
    } else if (lowerName.includes('adobe') || lowerName.includes('microsoft') || lowerName.includes('notion') || lowerName.includes('figma') || lowerName.includes('github')) {
      setCategory('software')
    } else if (lowerName.includes('xbox') || lowerName.includes('playstation') || lowerName.includes('game')) {
      setCategory('gaming')
    } else if (lowerName.includes('doordash') || lowerName.includes('uber')) {
      setCategory('food')
    } else {
      setCategory('other')
    }
    setStep(2)
  }

  const handleSubmit = async () => {
    if (!name || !amount || !renewalDate) {
      setError('Please fill in all required fields')
      return
    }

    setLoading(true)
    setError('')

    try {
      const { error: submitError } = await addSubscription({
        user_id: userId,
        name: name.trim(),
        amount: parseFloat(amount),
        category,
        billing_cycle: billingCycle,
        renewal_date: renewalDate,
        status: 'active',
        website_url: null,
        description: null,
        logo_url: null
      })

      if (submitError) throw submitError

      onSuccess()
      handleClose()
    } catch (err: any) {
      setError(err.message || 'Failed to add subscription')
      setLoading(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div 
        className="absolute inset-0 bg-black/80 backdrop-blur-sm"
        onClick={handleClose}
      />

      <div className="relative w-full max-w-lg bg-[#0c0c0e] rounded-3xl border border-white/10 overflow-hidden max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="sticky top-0 bg-[#0c0c0e] border-b border-white/10 px-6 py-5 flex items-center justify-between z-10">
          <div>
            <h2 className="text-xl font-semibold">Add Subscription</h2>
            <p className="text-sm text-white/50 mt-1">Step {step} of 2</p>
          </div>
          <button
            onClick={handleClose}
            className="p-2 hover:bg-white/10 rounded-full transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Error */}
        {error && (
          <div className="mx-6 mt-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
            {error}
          </div>
        )}

        {/* Step 1: Choose Service */}
        {step === 1 && (
          <div className="p-8 space-y-8">
            <div>
              <p className="text-sm text-white/70 mb-4">Popular services</p>
              <div className="grid grid-cols-3 gap-3">
                {POPULAR_SERVICES.slice(0, 6).map((service) => (
                  <button
                    key={service}
                    onClick={() => handleSelectPopular(service)}
                    className="p-4 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 hover:border-white/20 transition-all text-center"
                  >
                    <span className="text-sm font-medium">{service}</span>
                  </button>
                ))}
              </div>
            </div>

            <div className="border-t border-white/10 pt-8">
              <p className="text-sm text-white/70 mb-4">Or enter custom name</p>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g., Netflix, Gym, Spotify"
                className="input"
              />
            </div>

            <button
              onClick={() => name && setStep(2)}
              disabled={!name}
              className="w-full btn-primary disabled:opacity-50 py-4"
            >
              Continue
            </button>
          </div>
        )}

        {/* Step 2: Details */}
        {step === 2 && (
          <div className="p-8 space-y-8">
            {/* Amount */}
            <div className="space-y-3">
              <label className="block text-sm font-medium text-white/70">Amount</label>
              <div className="relative">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none">
                  <DollarSign className="w-5 h-5" />
                </div>
                <input
                  type="number"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="0.00"
                  step="0.01"
                  min="0"
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-12 py-4 text-lg text-white placeholder:text-white/30 focus:outline-none focus:border-white/30 transition-colors"
                  required
                />
              </div>
            </div>

            {/* Billing Cycle */}
            <div className="space-y-3">
              <label className="block text-sm font-medium text-white/70">Billing Cycle</label>
              <div className="grid grid-cols-3 gap-3">
                {(['monthly', 'yearly', 'weekly'] as const).map((cycle) => (
                  <button
                    key={cycle}
                    onClick={() => setBillingCycle(cycle)}
                    className={`p-4 rounded-xl border text-sm font-medium transition-all ${
                      billingCycle === cycle
                        ? 'bg-white text-black border-white'
                        : 'bg-white/5 border-white/10 hover:border-white/30'
                    }`}
                  >
                    {cycle.charAt(0).toUpperCase() + cycle.slice(1)}
                  </button>
                ))}
              </div>
            </div>

            {/* Renewal Date */}
            <div className="space-y-3">
              <label className="block text-sm font-medium text-white/70">Next Renewal Date</label>
              <div className="relative">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none">
                  <Calendar className="w-5 h-5" />
                </div>
                <input
                  type="date"
                  value={renewalDate}
                  onChange={(e) => setRenewalDate(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-12 py-4 text-white focus:outline-none focus:border-white/30 transition-colors"
                  required
                />
              </div>
            </div>

            {/* Category */}
            <div className="space-y-3">
              <label className="block text-sm font-medium text-white/70">Category</label>
              <div className="relative">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none">
                  <Tag className="w-5 h-5" />
                </div>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value as SubscriptionCategory)}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-12 py-4 text-white appearance-none cursor-pointer focus:outline-none focus:border-white/30 transition-colors"
                >
                  {SUBSCRIPTION_CATEGORIES.map((cat) => (
                    <option key={cat.value} value={cat.value} className="bg-[#1c1c1e]">
                      {cat.label}
                    </option>
                  ))}
                </select>
                <div className="absolute right-4 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none">
                  <ChevronDown className="w-5 h-5" />
                </div>
              </div>
            </div>

            {/* Buttons */}
            <div className="flex gap-4 pt-4">
              <button
                onClick={() => setStep(1)}
                className="flex-1 py-4 rounded-full border border-white/20 text-white font-medium hover:bg-white/5 transition-all"
              >
                Back
              </button>
              <button
                onClick={handleSubmit}
                disabled={loading || !amount || !renewalDate}
                className="flex-1 bg-blue-500 hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium py-4 rounded-full transition-all"
              >
                {loading ? (
                  <Loader2 className="w-5 h-5 animate-spin mx-auto" />
                ) : (
                  'Add Subscription'
                )}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
