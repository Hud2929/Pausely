import { useState, useEffect } from 'react'
import AICancellationAgent from './ai/AICancellationAgent'
import AISmartPausing from './ai/AISmartPausing'
import AIDailyBriefing from './ai/AIDailyBriefing'
import AddSubscriptionModal from './AddSubscriptionModal'
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
  Crown,
  Loader2,
  AlertCircle
} from 'lucide-react'
import { signOut, getCurrentUser } from '../lib/supabase'
import { 
  getUserSubscriptions, 
  getUserProfile
} from '../lib/database'
import type { Subscription, UserProfile } from '../types/subscription'

type View = 'dashboard' | 'ai-cancellation' | 'ai-pausing' | 'ai-briefing'

export default function Dashboard() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([])
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const [userId, setUserId] = useState<string>('')
  const [loading, setLoading] = useState(true)
  const [activeView, setActiveView] = useState<View>('dashboard')
  const [isAddModalOpen, setIsAddModalOpen] = useState(false)

  // Load user data
  useEffect(() => {
    loadUserData()
  }, [])

  const loadUserData = async () => {
    try {
      setLoading(true)
      const user = await getCurrentUser()
      if (!user) return
      
      setUserId(user.id)
      
      const [subsData, profileData] = await Promise.all([
        getUserSubscriptions(user.id),
        getUserProfile(user.id)
      ])
      
      if (subsData) setSubscriptions(subsData)
      if (profileData) setProfile(profileData)
    } catch (error) {
      console.error('Error loading data:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleSignOut = async () => {
    await signOut()
    window.location.reload()
  }

  const monthlySpending = subscriptions.reduce((acc, sub) => 
    sub.status === 'active' ? acc + sub.amount : acc, 0
  )

  // AI Views
  if (activeView === 'ai-cancellation') {
    return <AICancellationAgent subscriptions={subscriptions} onBack={() => setActiveView('dashboard')} />
  }

  if (activeView === 'ai-pausing') {
    return <AISmartPausing subscriptions={subscriptions} onBack={() => setActiveView('dashboard')} />
  }

  if (activeView === 'ai-briefing') {
    return <AIDailyBriefing subscriptions={subscriptions} onBack={() => setActiveView('dashboard')} />
  }

  return (
    <div className="min-h-screen bg-black text-white">
      {/* Header */}
      <header className="glass sticky top-0 z-40 border-b border-white/5">
        <div className="container mx-auto max-w-6xl px-4 flex items-center justify-between py-4">
          <div className="flex items-center gap-3">
            <span className="text-xl font-bold">Pausely</span>
            {profile?.plan_type === 'pro' && (
              <span className="px-2 py-0.5 rounded-full bg-gradient-to-r from-yellow-500/20 to-orange-500/20 border border-yellow-500/30 text-yellow-400 text-xs font-medium flex items-center gap-1">
                <Crown className="w-3 h-3" />
                Pro
              </span>
            )}
          </div>
          
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

      <main className="container mx-auto max-w-6xl px-4 py-8 pb-32">
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <Loader2 className="w-8 h-8 animate-spin" />
          </div>
        ) : (
          <>
            {/* Welcome */}
            <div className="mb-8">
              <h1 className="text-3xl font-bold mb-2">Welcome back{profile?.full_name ? `, ${profile.full_name.split(' ')[0]}` : ''} 👋</h1>
              <p className="text-white/60">Here's your subscription overview</p>
            </div>

            {/* AI Features */}
            <div className="mb-10">
              <h2 className="text-lg font-semibold mb-4 text-white/70">AI Features</h2>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
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
                  <p className="text-sm text-white/50">AI drafts cancellation emails</p>
                </div>

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
                  <p className="text-sm text-white/50">Detect unused subscriptions</p>
                </div>

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
                  <p className="text-sm text-white/50">Morning insights email</p>
                </div>
              </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 gap-4 mb-8">
              <div className="card">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-12 h-12 rounded-xl bg-blue-500/20 flex items-center justify-center">
                    <Wallet className="w-6 h-6 text-blue-400" />
                  </div>
                  <div>
                    <p className="text-sm text-white/60">Monthly Spending</p>
                    <p className="text-2xl font-bold">${monthlySpending.toFixed(2)}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2 text-green-400 text-sm">
                  <TrendingDown className="w-4 h-4" />
                  <span>Track your spending</span>
                </div>
              </div>

              <div className="card">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-12 h-12 rounded-xl bg-green-500/20 flex items-center justify-center">
                    <Gift className="w-6 h-6 text-green-400" />
                  </div>
                  <div>
                    <p className="text-sm text-white/60">Subscriptions</p>
                    <p className="text-2xl font-bold">{subscriptions.length}</p>
                  </div>
                </div>
                <div className="text-white/60 text-sm">
                  {subscriptions.filter(s => s.status === 'active').length} active
                </div>
              </div>
            </div>

            {/* Subscriptions List */}
            <div className="mb-6 flex items-center justify-between">
              <h2 className="text-xl font-semibold">Your Subscriptions</h2>
              <button 
                onClick={() => setIsAddModalOpen(true)}
                className="btn-primary text-sm py-2 px-4"
              >
                <Plus className="w-4 h-4 mr-2" />
                Add New
              </button>
            </div>

            {subscriptions.length === 0 ? (
              <div className="card text-center py-12">
                <AlertCircle className="w-12 h-12 text-white/30 mx-auto mb-4" />
                <h3 className="text-lg font-semibold mb-2">No subscriptions yet</h3>
                <p className="text-white/60 mb-6">Add your first subscription to start tracking</p>
                <button 
                  onClick={() => setIsAddModalOpen(true)}
                  className="btn-primary"
                >
                  Add Subscription
                </button>
              </div>
            ) : (
              <div className="space-y-3">
                {subscriptions.map((sub) => (
                  <div key={sub.id} className="card flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center text-lg font-semibold">
                        {sub.name[0]}
                      </div>
                      <div>
                        <p className="font-semibold">{sub.name}</p>
                        <p className={`text-sm ${
                          sub.status === 'active' ? 'text-green-400' : 
                          sub.status === 'paused' ? 'text-orange-400' : 'text-red-400'
                        }`}>
                          {sub.status.charAt(0).toUpperCase() + sub.status.slice(1)}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-4">
                      <span className="font-semibold">${sub.amount}</span>
                      <ChevronRight className="w-5 h-5 text-white/40" />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </main>

      <AddSubscriptionModal
        userId={userId}
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        onSuccess={loadUserData}
      />
    </div>
  )
}
