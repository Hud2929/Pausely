import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import AICancellationAgent from './ai/AICancellationAgent'
import AISmartPausing from './ai/AISmartPausing'
import AIDailyBriefing from './ai/AIDailyBriefing'
import { 
  Wallet, 
  TrendingDown, 
  Gift, 
  Plus, 
  Settings, 
  LogOut,
  ChevronRight,
  Bot,
  PauseCircle,
  Mail,
  ArrowLeft
} from 'lucide-react'

type View = 'dashboard' | 'ai-cancellation' | 'ai-pausing' | 'ai-briefing'

export default function Dashboard() {
  const [monthlySpend] = useState(247)
  const [user, setUser] = useState<any>(null)
  const [activeView, setActiveView] = useState<View>('dashboard')

  useEffect(() => {
    const getUser = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      setUser(user)
    }
    getUser()
  }, [])

  const handleSignOut = async () => {
    await supabase.auth.signOut()
  }

  if (activeView === 'ai-cancellation') {
    return (
      <>
        <button 
          onClick={() => setActiveView('dashboard')}
          className="fixed top-4 left-4 z-50 glass px-4 py-2 rounded-full flex items-center gap-2"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
        <AICancellationAgent />
      </>
    )
  }

  if (activeView === 'ai-pausing') {
    return (
      <>
        <button 
          onClick={() => setActiveView('dashboard')}
          className="fixed top-4 left-4 z-50 glass px-4 py-2 rounded-full flex items-center gap-2"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
        <AISmartPausing />
      </>
    )
  }

  if (activeView === 'ai-briefing') {
    return (
      <>
        <button 
          onClick={() => setActiveView('dashboard')}
          className="fixed top-4 left-4 z-50 glass px-4 py-2 rounded-full flex items-center gap-2"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
        <AIDailyBriefing />
      </>
    )
  }

  return (
    <div className="min-h-screen bg-black text-white">
      {/* Header */}
      <header className="glass sticky top-0 z-50 border-b border-white/5">
        <div className="container flex items-center justify-between py-4">
          <span className="text-xl font-bold">Pausely</span>
          <div className="flex items-center gap-4">
            <button className="p-2 hover:bg-white/10 rounded-full transition-colors">
              <Settings className="w-5 h-5" />
            </button>
            <button 
              onClick={handleSignOut}
              className="p-2 hover:bg-white/10 rounded-full transition-colors"
            >
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        </div>
      </header>

      <main className="container py-8 pb-24">
        {/* Welcome */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2">Welcome back{user?.email ? `, ${user.email.split('@')[0]}` : ''} 👋</h1>
          <p className="text-white/60">Here's your subscription overview</p>
        </div>

        {/* AI Features Grid */}
        <div className="mb-10">
          <h2 className="text-lg font-semibold mb-4 text-white/70">AI Features</h2>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* AI Cancellation Agent */}
            <div 
              onClick={() => setActiveView('ai-cancellation')}
              className="card bg-gradient-to-br from-purple-500/10 to-pink-500/10 border-purple-500/20 cursor-pointer group"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="w-12 h-12 rounded-2xl bg-purple-500/20 flex items-center justify-center">
                  <Bot className="w-6 h-6 text-purple-400" />
                </div>
                <ChevronRight className="w-5 h-5 text-white/30 group-hover:text-white/60 transition-colors" />
              </div>
              <h3 className="font-semibold mb-1">Cancellation Agent</h3>
              <p className="text-sm text-white/50">AI drafts cancellation emails for you</p>
            </div>

            {/* AI Smart Pausing */}
            <div 
              onClick={() => setActiveView('ai-pausing')}
              className="card bg-gradient-to-br from-blue-500/10 to-cyan-500/10 border-blue-500/20 cursor-pointer group"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="w-12 h-12 rounded-2xl bg-blue-500/20 flex items-center justify-center">
                  <PauseCircle className="w-6 h-6 text-blue-400" />
                </div>
                <ChevronRight className="w-5 h-5 text-white/30 group-hover:text-white/60 transition-colors" />
              </div>
              <h3 className="font-semibold mb-1">Smart Pausing</h3>
              <p className="text-sm text-white/50">Detect unused subscriptions automatically</p>
            </div>

            {/* AI Daily Briefing */}
            <div 
              onClick={() => setActiveView('ai-briefing')}
              className="card bg-gradient-to-br from-orange-500/10 to-amber-500/10 border-orange-500/20 cursor-pointer group"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="w-12 h-12 rounded-2xl bg-orange-500/20 flex items-center justify-center">
                  <Mail className="w-6 h-6 text-orange-400" />
                </div>
                <ChevronRight className="w-5 h-5 text-white/30 group-hover:text-white/60 transition-colors" />
              </div>
              <h3 className="font-semibold mb-1">Daily Briefing</h3>
              <p className="text-sm text-white/50">Morning email with personalized insights</p>
            </div>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-2 gap-4 mb-8">
          <div className="card">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 rounded-xl bg-blue-500/20 flex items-center justify-center">
                <Wallet className="w-6 h-6 text-blue-400" />
              </div>
              <div>
                <p className="text-sm text-white/60">Monthly Spending</p>
                <p className="text-2xl font-bold">${monthlySpend}.00</p>
              </div>
            </div>
            <div className="flex items-center gap-2 text-green-400 text-sm">
              <TrendingDown className="w-4 h-4" />
              <span>$89 saved this month</span>
            </div>
          </div>

          <div className="card">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 rounded-xl bg-green-500/20 flex items-center justify-center">
                <Gift className="w-6 h-6 text-green-400" />
              </div>
              <div>
                <p className="text-sm text-white/60">Free Perks Found</p>
                <p className="text-2xl font-bold">3</p>
              </div>
            </div>
            <div className="text-white/60 text-sm">
              Potential savings: $42/month
            </div>
          </div>
        </div>

        {/* Subscriptions List */}
        <div className="mb-6 flex items-center justify-between">
          <h2 className="text-xl font-semibold">Your Subscriptions</h2>
          <button className="btn-primary text-sm py-2 px-4">
            <Plus className="w-4 h-4 mr-2" />
            Add New
          </button>
        </div>

        <div className="space-y-3">
          {[
            { name: 'Netflix', amount: 15.99, change: '↓ 40%', color: 'text-red-400', initial: 'N' },
            { name: 'Spotify', amount: 9.99, change: '↓ 20%', color: 'text-green-400', initial: 'S' },
            { name: 'Gym Membership', amount: 49.99, change: 'Paused', color: 'text-orange-400', initial: 'G' },
          ].map((sub, i) => (
            <div key={i} className="card flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center text-lg font-semibold">
                  {sub.initial}
                </div>
                <div>
                  <p className="font-semibold">{sub.name}</p>
                  <p className={`text-sm ${sub.color}`}>{sub.change}</p>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <span className="font-semibold">${sub.amount}</span>
                <ChevronRight className="w-5 h-5 text-white/40" />
              </div>
            </div>
          ))}
        </div>

        {/* Insights */}
        <div className="mt-8 card bg-gradient-to-br from-blue-500/10 to-purple-500/10 border-blue-500/20">
          <h3 className="font-semibold mb-2">💡 AI Insight</h3>
          <p className="text-white/70 text-sm">
            You're spending 23% more on streaming services than last month. 
            Consider pausing Netflix for 2 months since you haven't watched anything in 3 weeks.
          </p>
        </div>
      </main>
    </div>
  )
}
