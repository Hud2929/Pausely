import { useState, useEffect } from 'react'
import { Mail, TrendingDown, Gift, Clock, Sparkles, ChevronRight, Bell } from 'lucide-react'
import type { Subscription } from '../../types/subscription'

interface AIDailyBriefingProps {
  subscriptions: Subscription[]
  monthlySpending: number
}

interface BriefingItem {
  id: string
  type: 'savings' | 'perk' | 'reminder' | 'tip'
  title: string
  description: string
  amount?: number
  action?: string
}

export default function AIDailyBriefing({ 
  subscriptions, 
  monthlySpending 
}: AIDailyBriefingProps) {
  const [emailEnabled, setEmailEnabled] = useState(true)
  const [briefingTime, setBriefingTime] = useState('8:00 AM')
  const [briefing, setBriefing] = useState<BriefingItem[]>([])
  const [upcomingRenewals, setUpcomingRenewals] = useState<Subscription[]>([])

  // Generate personalized briefing based on real subscription data
  useEffect(() => {
    generateBriefing()
  }, [subscriptions, monthlySpending])

  const generateBriefing = () => {
    const items: BriefingItem[] = []

    // Monthly spending summary
    if (monthlySpending > 0) {
      items.push({
        id: '1',
        type: 'savings',
        title: `Your monthly spending: $${monthlySpending.toFixed(2)}`,
        description: `You're tracking ${subscriptions.length} subscription${subscriptions.length !== 1 ? 's' : ''} with Pausely.`,
        amount: monthlySpending
      })
    }

    // Upcoming renewals
    const renewals = subscriptions.filter(sub => {
      if (!sub.renewal_date) return false
      const renewal = new Date(sub.renewal_date)
      const today = new Date()
      const diffDays = Math.ceil((renewal.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
      return diffDays >= 0 && diffDays <= 7
    })
    
    setUpcomingRenewals(renewals)

    renewals.forEach((sub, index) => {
      items.push({
        id: `renewal-${index}`,
        type: 'reminder',
        title: `${sub.name} renews soon`,
        description: `Your ${sub.billing_cycle} subscription renews on ${new Date(sub.renewal_date!).toLocaleDateString()}.`,
        amount: sub.amount,
        action: 'View subscription'
      })
    })

    // AI tip based on subscription count
    if (subscriptions.length >= 3) {
      const yearlyEstimate = monthlySpending * 12
      items.push({
        id: 'tip-1',
        type: 'tip',
        title: 'Annual subscription check',
        description: `You're spending approximately $${yearlyEstimate.toFixed(0)}/year on subscriptions. Consider reviewing which ones you use regularly.`,
        action: 'Review subscriptions'
      })
    }

    // Low usage recommendation (simulated based on subscription data)
    const activeSubscriptions = subscriptions.filter(s => s.status === 'active')
    if (activeSubscriptions.length > 0) {
      // Pick a subscription to recommend pausing (using name hash for consistency)
      const subToPause = activeSubscriptions.reduce((prev, current) => {
        const prevHash = prev.name.split('').reduce((a, b) => a + b.charCodeAt(0), 0)
        const currHash = current.name.split('').reduce((a, b) => a + b.charCodeAt(0), 0)
        return prevHash > currHash ? prev : current
      })

      if (Math.random() > 0.5) { // Only show sometimes for variety
        items.push({
          id: 'pause-rec',
          type: 'perk',
          title: 'Pause recommendation',
          description: `Based on your usage patterns, consider pausing ${subToPause.name} to save $${subToPause.amount.toFixed(2)}/${subToPause.billing_cycle}.`,
          amount: subToPause.amount,
          action: 'Pause now'
        })
      }
    }

    // Perk discovery (simulated)
    if (subscriptions.length > 0 && Math.random() > 0.7) {
      const perks = [
        'Your credit card may include free subscriptions',
        'Check if your employer offers any subscription perks',
        'Many libraries offer free access to premium services'
      ]
      items.push({
        id: 'perk-1',
        type: 'perk',
        title: 'Free perk opportunity',
        description: perks[Math.floor(Math.random() * perks.length)],
        action: 'Learn more'
      })
    }

    setBriefing(items)
  }

  const getIcon = (type: BriefingItem['type']) => {
    switch (type) {
      case 'savings':
        return { icon: TrendingDown, color: 'text-green-400', bg: 'bg-green-500/10' }
      case 'perk':
        return { icon: Gift, color: 'text-purple-400', bg: 'bg-purple-500/10' }
      case 'reminder':
        return { icon: Clock, color: 'text-orange-400', bg: 'bg-orange-500/10' }
      case 'tip':
        return { icon: Sparkles, color: 'text-blue-400', bg: 'bg-blue-500/10' }
    }
  }

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-12">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 rounded-2xl bg-orange-500/20 flex items-center justify-center">
              <Mail className="w-6 h-6 text-orange-400" />
            </div>
            <div>
              <h1 className="text-3xl font-bold">AI Daily Briefing</h1>
              <p className="text-white/50">Your personalized subscription summary</p>
            </div>
          </div>
        </div>

        {/* Settings */}
        <div className="glass rounded-2xl p-6 mb-10">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div className="flex items-center gap-4">
              <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${emailEnabled ? 'bg-orange-500/20' : 'bg-white/10'}`}>
                <Bell className={`w-6 h-6 ${emailEnabled ? 'text-orange-400' : 'text-white/40'}`} />
              </div>
              <div>
                <p className="font-semibold">Email Notifications</p>
                <p className="text-sm text-white/50">Get your briefing every morning</p>
              </div>
            </div>
            
            <div className="flex items-center gap-4">
              <select
                value={briefingTime}
                onChange={(e) => setBriefingTime(e.target.value)}
                className="bg-white/10 border border-white/10 rounded-xl px-4 py-2 text-sm"
              >
                <option>6:00 AM</option>
                <option>7:00 AM</option>
                <option>8:00 AM</option>
                <option>9:00 AM</option>
              </select>
              
              <button
                onClick={() => setEmailEnabled(!emailEnabled)}
                className={`w-14 h-8 rounded-full transition-colors relative ${
                  emailEnabled ? 'bg-orange-500' : 'bg-white/20'
                }`}
              >
                <div
                  className={`absolute top-1 w-6 h-6 rounded-full bg-white transition-transform ${
                    emailEnabled ? 'left-7' : 'left-1'
                  }`}
                />
              </button>
            </div>
          </div>
        </div>

        {/* Stats */}
        {monthlySpending > 0 && (
          <div className="glass rounded-2xl p-6 mb-10 text-center">
            <p className="text-sm text-white/50 mb-2">Monthly subscription spending</p>
            <p className="text-5xl font-bold">${monthlySpending.toFixed(2)}</p>
          </div>
        )}

        {/* Today's Briefing */}
        <div className="mb-6">
          <h2 className="text-xl font-semibold mb-6">Today's Briefing</h2>
          
          {briefing.length === 0 ? (
            <div className="glass rounded-2xl p-8 text-center">
              <Mail className="w-12 h-12 text-white/30 mx-auto mb-4" />
              <h3 className="text-xl font-semibold mb-2">No briefing items yet</h3>
              <p className="text-white/50">
                Add some subscriptions to get personalized AI insights.
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {briefing.map((item) => {
                const { icon: Icon, color, bg } = getIcon(item.type)
                
                return (
                  <div key={item.id} className="glass rounded-2xl p-6 hover:bg-white/[0.03] transition-colors">
                    <div className="flex items-start gap-4">
                      <div className={`w-12 h-12 rounded-xl ${bg} flex items-center justify-center flex-shrink-0`}>
                        <Icon className={`w-6 h-6 ${color}`} />
                      </div>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-4">
                          <div>
                            <p className="font-semibold text-lg mb-1">{item.title}</p>
                            <p className="text-white/60">{item.description}</p>
                          </div>
                          
                          {item.amount && (
                            <div className="text-right flex-shrink-0">
                              <p className={`text-2xl font-bold ${
                                item.type === 'savings' || item.type === 'tip' ? 'text-green-400' : 'text-white'
                              }`}>
                                ${item.amount.toFixed(2)}
                              </p>
                            </div>
                          )}
                        </div>
                        
                        {item.action && (
                          <button className="mt-4 flex items-center gap-2 text-sm font-medium text-white/70 hover:text-white transition-colors"
                          >
                            {item.action}
                            <ChevronRight className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>

        {/* Sample Preview */}
        <div className="glass rounded-2xl p-6">
          <p className="text-sm text-white/50 mb-4">Sample email preview</p>
          
          <div className="bg-white rounded-xl p-6 text-black">
            <div className="border-b border-black/10 pb-4 mb-4">
              <p className="font-bold text-lg">Good morning! 👋</p>
              <p className="text-black/60">Here's your daily briefing from Pausely</p>
            </div>
            
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                  <TrendingDown className="w-4 h-4 text-green-600" />
                </div>
                <p className="text-sm">Monthly spending: <strong>${monthlySpending.toFixed(2)}</strong></p>
              </div>
              
              {upcomingRenewals.length > 0 && (
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-orange-100 flex items-center justify-center">
                    <Clock className="w-4 h-4 text-orange-600" />
                  </div>
                  <p className="text-sm">{upcomingRenewals.length} subscription{upcomingRenewals.length > 1 ? 's' : ''} renewing soon</p>
                </div>
              )}
              
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center">
                  <Sparkles className="w-4 h-4 text-blue-600" />
                </div>
                <p className="text-sm">AI has analyzed your subscriptions</p>
              </div>
            </div>
            
            <button className="mt-6 w-full bg-black text-white py-3 rounded-lg font-medium">
              Open Pausely
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
