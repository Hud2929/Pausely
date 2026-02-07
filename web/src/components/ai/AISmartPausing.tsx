import { useState } from 'react'
import { PauseCircle, TrendingDown, Clock, AlertTriangle, Play } from 'lucide-react'

interface Subscription {
  id: string
  name: string
  amount: number
  lastUsed: string
  usageScore: number
  status: 'active' | 'paused' | 'recommended'
}

const mockSubscriptions: Subscription[] = [
  {
    id: '1',
    name: 'Netflix',
    amount: 15.99,
    lastUsed: '3 weeks ago',
    usageScore: 15,
    status: 'recommended'
  },
  {
    id: '2',
    name: 'Adobe Creative Cloud',
    amount: 54.99,
    lastUsed: '5 days ago',
    usageScore: 65,
    status: 'active'
  },
  {
    id: '3',
    name: 'Gym Membership',
    amount: 49.99,
    lastUsed: '2 months ago',
    usageScore: 5,
    status: 'recommended'
  },
  {
    id: '4',
    name: 'Spotify',
    amount: 9.99,
    lastUsed: 'Yesterday',
    usageScore: 95,
    status: 'active'
  }
]

export default function AISmartPausing() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>(mockSubscriptions)

  const handlePause = (id: string) => {
    setSubscriptions(subs => 
      subs.map(sub => 
        sub.id === id ? { ...sub, status: 'paused' as const } : sub
      )
    )
  }

  const handleResume = (id: string) => {
    setSubscriptions(subs => 
      subs.map(sub => 
        sub.id === id ? { ...sub, status: 'active' as const } : sub
      )
    )
  }

  const potentialSavings = subscriptions
    .filter(s => s.status === 'recommended')
    .reduce((acc, s) => acc + s.amount, 0)

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-12">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 rounded-2xl bg-blue-500/20 flex items-center justify-center">
              <PauseCircle className="w-6 h-6 text-blue-400" />
            </div>
            <div>
              <h1 className="text-3xl font-bold">AI Smart Pausing</h1>
              <p className="text-white/50">Automatically detects unused subscriptions</p>
            </div>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 gap-6 mb-10">
          <div className="glass rounded-2xl p-6">
            <div className="flex items-center gap-2 mb-2">
              <TrendingDown className="w-5 h-5 text-green-400" />
              <span className="text-sm text-white/50">Potential Monthly Savings</span>
            </div>
            <p className="text-4xl font-bold text-green-400">${potentialSavings.toFixed(2)}</p>
          </div>
          
          <div className="glass rounded-2xl p-6">
            <div className="flex items-center gap-2 mb-2">
              <Clock className="w-5 h-5 text-blue-400" />
              <span className="text-sm text-white/50">Tracking Since</span>
            </div>
            <p className="text-4xl font-bold">14 days</p>
          </div>
        </div>

        {/* Recommendations */}
        <div className="mb-6">
          <h2 className="text-xl font-semibold mb-6">AI Recommendations</h2>
          
          <div className="space-y-4">
            {subscriptions.map((sub) => (
              <div
                key={sub.id}
                className={`glass rounded-2xl p-6 transition-all ${
                  sub.status === 'recommended' ? 'border-blue-500/30' : ''
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center text-lg font-semibold">
                      {sub.name[0]}
                    </div>
                    <div>
                      <p className="font-semibold text-lg">{sub.name}</p>
                      <div className="flex items-center gap-2 text-sm">
                        <span className="text-white/50">Last used: {sub.lastUsed}</span>
                        {sub.status === 'recommended' && (
                          <span className="px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400 text-xs">
                            AI Recommended
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex items-center gap-6">
                    <div className="text-right">
                      <p className="text-2xl font-bold">${sub.amount}</p>
                      <p className="text-sm text-white/50">/month</p>
                    </div>
                    
                    {sub.status === 'active' && (
                      <button
                        className="px-6 py-3 rounded-xl bg-blue-500/20 text-blue-400 font-medium hover:bg-blue-500/30 transition-colors"
                      >
                        Pause
                      </button>
                    )}
                    
                    {sub.status === 'recommended' && (
                      <button
                        onClick={() => handlePause(sub.id)}
                        className="px-6 py-3 rounded-xl bg-blue-500 text-white font-medium hover:bg-blue-600 transition-colors flex items-center gap-2"
                      >
                        <PauseCircle className="w-5 h-5" />
                        Pause Now
                      </button>
                    )}
                    
                    {sub.status === 'paused' && (
                      <button
                        onClick={() => handleResume(sub.id)}
                        className="px-6 py-3 rounded-xl bg-green-500/20 text-green-400 font-medium hover:bg-green-500/30 transition-colors flex items-center gap-2"
                      >
                        <Play className="w-5 h-5" />
                        Resume
                      </button>
                    )}
                  </div>
                </div>
                
                {/* Usage Bar */}
                <div className="mt-4">
                  <div className="flex items-center justify-between text-sm mb-2">
                    <span className="text-white/50">Usage Score</span>
                    <span className={sub.usageScore < 30 ? 'text-red-400' : sub.usageScore < 70 ? 'text-yellow-400' : 'text-green-400'}>
                      {sub.usageScore}%
                    </span>
                  </div>
                  <div className="h-2 bg-white/10 rounded-full overflow-hidden">
                    <div 
                      className={`h-full rounded-full transition-all ${
                        sub.usageScore < 30 ? 'bg-red-400' : sub.usageScore < 70 ? 'bg-yellow-400' : 'bg-green-400'
                      }`}
                      style={{ width: `${sub.usageScore}%` }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Info Box */}
        <div className="glass rounded-2xl p-6 flex items-start gap-4">
          <AlertTriangle className="w-6 h-6 text-yellow-400 flex-shrink-0 mt-0.5" />
          <div>
            <p className="font-medium mb-1">How it works</p>
            <p className="text-white/60 text-sm">
              Our AI analyzes your login activity and usage patterns. When you haven't used a subscription 
              in 2+ weeks, it recommends pausing. You keep all your data and can resume anytime with one click.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
