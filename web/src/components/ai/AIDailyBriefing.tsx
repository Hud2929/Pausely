import { useState } from 'react'
import { Mail, TrendingDown, Gift, Clock, Sparkles, ChevronRight, Bell } from 'lucide-react'

interface BriefingItem {
  id: string
  type: 'savings' | 'perk' | 'reminder' | 'tip'
  title: string
  description: string
  amount?: number
  action?: string
}

const mockBriefing: BriefingItem[] = [
  {
    id: '1',
    type: 'savings',
    title: 'You saved $47 this week',
    description: 'By pausing your Gym Membership and switching to Spotify Family, you saved $47.23 this week.',
    amount: 47.23,
    action: 'View details'
  },
  {
    id: '2',
    type: 'perk',
    title: 'New free perk found',
    description: 'Your American Express Platinum includes free Disney+ ($13.99/mo value). You\'re currently paying for it separately.',
    action: 'Claim now'
  },
  {
    id: '3',
    type: 'reminder',
    title: 'Netflix renews tomorrow',
    description: 'You\'ve only watched 2 hours this month. Consider pausing for $15.99 savings.',
    amount: 15.99,
    action: 'Pause subscription'
  },
  {
    id: '4',
    type: 'tip',
    title: 'AI Tip: Annual vs Monthly',
    description: 'Switching Adobe from monthly to annual saves you $120/year. You use it daily, so it\'s worth it.',
    amount: 120,
    action: 'Switch to annual'
  }
]

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

export default function AIDailyBriefing() {
  const [emailEnabled, setEmailEnabled] = useState(true)
  const [briefingTime, setBriefingTime] = useState('8:00 AM')

  const totalSavings = mockBriefing
    .filter(item => item.type === 'savings' || item.type === 'reminder')
    .reduce((acc, item) => acc + (item.amount || 0), 0)

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
              <p className="text-white/50">Your personalized morning summary</p>
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
        <div className="glass rounded-2xl p-6 mb-10 text-center">
          <p className="text-sm text-white/50 mb-2">Potential savings this week</p>
          <p className="text-5xl font-bold text-green-400">${totalSavings.toFixed(2)}</p>
        </div>

        {/* Today's Briefing */}
        <div className="mb-6">
          <h2 className="text-xl font-semibold mb-6">Today's Briefing</h2>
          
          <div className="space-y-4">
            {mockBriefing.map((item) => {
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
                            <p className={`text-2xl font-bold ${item.type === 'savings' || item.type === 'tip' ? 'text-green-400' : 'text-white'}`}>
                              ${item.amount}
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
        </div>

        {/* Sample Preview */}
        <div className="glass rounded-2xl p-6">
          <p className="text-sm text-white/50 mb-4">Sample email preview</p>
          
          <div className="bg-white rounded-xl p-6 text-black">
            <div className="border-b border-black/10 pb-4 mb-4">
              <p className="font-bold text-lg">Good morning, Hudson! 👋</p>
              <p className="text-black/60">Here's your daily briefing from Pausely</p>
            </div>
            
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                  <TrendingDown className="w-4 h-4 text-green-600" />
                </div>
                <p className="text-sm">You saved <strong>$47</strong> this week</p>
              </div>
              
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center">
                  <Gift className="w-4 h-4 text-purple-600" />
                </div>
                <p className="text-sm">New perk: Free Disney+ with Amex</p>
              </div>
              
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-orange-100 flex items-center justify-center">
                  <Clock className="w-4 h-4 text-orange-600" />
                </div>
                <p className="text-sm">Netflix renews tomorrow</p>
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
