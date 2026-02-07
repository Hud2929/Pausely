import { useState } from 'react'
import { 
  Mail, 
  ArrowLeft,
  TrendingDown, 
  Gift, 
  Clock, 
  Sparkles,
  ChevronRight,
  Bell,
  DollarSign
} from 'lucide-react'
import type { Subscription } from '../../types/subscription'

interface AIDailyBriefingProps {
  subscriptions?: Subscription[]
  onBack?: () => void
}

interface BriefingItem {
  id: string
  type: 'savings' | 'perk' | 'reminder' | 'tip'
  title: string
  description: string
  amount?: number
  action?: string
  icon: any
  color: string
  bgColor: string
}

export default function AIDailyBriefing({ subscriptions = [], onBack }: AIDailyBriefingProps) {
  const [emailEnabled, setEmailEnabled] = useState(true)
  const [briefingTime, setBriefingTime] = useState('8:00 AM')
  const [showSettings, setShowSettings] = useState(false)

  // Calculate monthly spending
  const monthlySpending = subscriptions.reduce((acc, sub) => acc + sub.amount, 0)
  
  // Count upcoming renewals (within 7 days)
  const upcomingRenewals = subscriptions.filter(sub => {
    if (!sub.renewal_date) return false
    const renewal = new Date(sub.renewal_date)
    const today = new Date()
    const diffDays = Math.ceil((renewal.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
    return diffDays >= 0 && diffDays <= 7
  })

  // Generate briefing items
  const generateBriefing = (): BriefingItem[] => {
    const items: BriefingItem[] = []

    // Monthly spending summary
    if (monthlySpending > 0) {
      items.push({
        id: '1',
        type: 'savings',
        title: `Monthly spending: $${monthlySpending.toFixed(2)}`,
        description: `You're tracking ${subscriptions.length} subscription${subscriptions.length !== 1 ? 's' : ''}. That's $${(monthlySpending * 12).toFixed(0)}/year.`,
        amount: monthlySpending,
        action: 'View details',
        icon: DollarSign,
        color: 'text-green-400',
        bgColor: 'bg-green-500/10'
      })
    }

    // Upcoming renewals
    upcomingRenewals.forEach((sub, index) => {
      items.push({
        id: `renewal-${index}`,
        type: 'reminder',
        title: `${sub.name} renews soon`,
        description: `Your ${sub.billing_cycle} subscription renews on ${new Date(sub.renewal_date!).toLocaleDateString()}.`,
        amount: sub.amount,
        action: 'Manage',
        icon: Clock,
        color: 'text-orange-400',
        bgColor: 'bg-orange-500/10'
      })
    })

    // AI tip
    if (subscriptions.length >= 3) {
      items.push({
        id: 'tip-1',
        type: 'tip',
        title: 'Annual review recommended',
        description: `With ${subscriptions.length} subscriptions, review which ones you actually use regularly. Many people find they can pause 20-30%.`,
        action: 'Review now',
        icon: Sparkles,
        color: 'text-blue-400',
        bgColor: 'bg-blue-500/10'
      })
    }

    // Free perk suggestion
    items.push({
      id: 'perk-1',
      type: 'perk',
      title: 'Free perk opportunity',
      description: 'Check if your credit card offers free subscriptions. Many include Netflix, Spotify, or Calm memberships.',
      action: 'Learn more',
      icon: Gift,
      color: 'text-purple-400',
      bgColor: 'bg-purple-500/10'
    })

    return items
  }

  const briefing = generateBriefing()

  const getTypeLabel = (type: string) => {
    switch (type) {
      case 'savings': return 'Spending Summary'
      case 'reminder': return 'Renewal Reminder'
      case 'tip': return 'AI Tip'
      case 'perk': return 'Free Perk'
      default: return 'Insight'
    }
  }

  return (
    <div className="min-h-screen bg-black text-white">
      {/* Header */}
      <header className="sticky top-0 z-50 glass border-b border-white/10">
        <div className="container max-w-4xl mx-auto px-4 py-4 flex items-center justify-between">
          <button 
            onClick={onBack}
            className="flex items-center gap-2 text-white/70 hover:text-white transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
            <span className="hidden sm:inline">Back</span>
          </button>
          
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center">
              <Mail className="w-5 h-5" />
            </div>
            <div className="text-left">
              <h1 className="font-semibold">Daily Briefing</h1>
              <p className="text-xs text-white/50">AI-Powered</p>
            </div>
          </div>
          
          <button
            onClick={() => setShowSettings(!showSettings)}
            className="p-2 hover:bg-white/10 rounded-full transition-colors"
          >
            <Bell className="w-5 h-5" />
          </button>
        </div>
      </header>

      <main className="container max-w-4xl mx-auto px-4 py-8 pb-32">
        {/* Welcome */}
        <div className="text-center mb-8">
          <h2 className="text-2xl font-bold mb-2">Good morning! 👋</h2>
          <p className="text-white/60">Here's your personalized subscription summary</p>
        </div>

        {/* Quick Stats */}
        <div className="glass rounded-2xl p-6 mb-8">
          <div className="grid grid-cols-3 gap-6 text-center">
            <div>
              <p className="text-3xl font-bold text-white">{subscriptions.length}</p>
              <p className="text-sm text-white/50 mt-1">Subscriptions</p>
            </div>
            <div className="border-x border-white/10">
              <p className="text-3xl font-bold text-green-400">${monthlySpending.toFixed(0)}</p>
              <p className="text-sm text-white/50 mt-1">Monthly</p>
            </div>
            <div>
              <p className="text-3xl font-bold text-orange-400">{upcomingRenewals.length}</p>
              <p className="text-sm text-white/50 mt-1">Renewing Soon</p>
            </div>
          </div>
        </div>

        {/* Settings Panel */}
        {showSettings && (
          <div className="glass rounded-2xl p-6 mb-8">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <Bell className="w-5 h-5 text-orange-400" />
                <span className="font-medium">Email Notifications</span>
              </div>
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

            {emailEnabled && (
              <div className="flex items-center gap-3">
                <Clock className="w-5 h-5 text-white/50" />
                <span className="text-sm text-white/70">Delivery time:</span>
                <select
                  value={briefingTime}
                  onChange={(e) => setBriefingTime(e.target.value)}
                  className="bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm"
                >
                  <option>6:00 AM</option>
                  <option>7:00 AM</option>
                  <option>8:00 AM</option>
                  <option>9:00 AM</option>
                </select>
              </div>
            )}
          </div>
        )}

        {/* Briefing Items */}
        <div className="space-y-4">
          <h3 className="font-semibold text-lg mb-4">Today's Insights</h3>
          
          {briefing.map((item) => {
            const Icon = item.icon
            
            return (
              <div 
                key={item.id}
                className="glass rounded-2xl p-6 hover:bg-white/[0.03] transition-colors"
              >
                <div className="flex items-start gap-4">
                  <div className={`w-12 h-12 rounded-xl ${item.bgColor} flex items-center justify-center flex-shrink-0`}>
                    <Icon className={`w-6 h-6 ${item.color}`} />
                  </div>
                  
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-2">
                      <span className={`text-xs font-semibold px-2 py-1 rounded-full ${item.bgColor} ${item.color}`}>
                        {getTypeLabel(item.type)}
                      </span>
                      
                      {item.amount && (
                        <span className="text-lg font-bold">
                          ${item.amount.toFixed(2)}
                        </span>
                      )}
                    </div>
                    
                    <h4 className="font-semibold text-lg mb-2">{item.title}</h4>
                    <p className="text-white/60 leading-relaxed mb-4">{item.description}</p>
                    
                    {item.action && (
                      <button className="flex items-center gap-2 text-sm font-medium text-white/70 hover:text-white transition-colors">
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

        {/* Email Preview */}
        <div className="mt-8">
          <p className="text-sm text-white/50 mb-4">This is how your daily email looks</p>
          
          <div className="bg-white rounded-2xl p-6 text-black">
            <div className="border-b border-black/10 pb-4 mb-4">
              <p className="font-bold text-lg">Good morning! 👋</p>
              <p className="text-black/60">Here's your daily briefing from Pausely</p>
            </div>
            
            <div className="space-y-3">
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
            
            <button className="mt-6 w-full bg-black text-white py-3 rounded-xl font-medium">
              Open Pausely
            </button>
          </div>
        </div>
      </main>
    </div>
  )
}
