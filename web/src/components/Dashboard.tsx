import { useState, useEffect } from 'react'
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
  ArrowLeft,
  Crown,
  Sparkles,
  Loader2,
  AlertCircle
} from 'lucide-react'
import { getCurrentUser, signOut } from '../lib/supabase'
import { 
  getUserSubscriptions, 
  getUserProfile,
  calculateMonthlySpending,
  canAddSubscription
} from '../lib/database'
import { openCheckout, PLANS } from '../lib/lemonsqueezy'
import AddSubscriptionModal from './AddSubscriptionModal'
import AICancellationAgent from './ai/AICancellationAgent'
import AISmartPausing from './ai/AISmartPausing'
import AIDailyBriefing from './ai/AIDailyBriefing'
import type { Subscription, UserProfile } from '../types/subscription'

type View = 'dashboard' | 'ai-cancellation' | 'ai-pausing' | 'ai-briefing'

export default function Dashboard() {
  const [user, setUser] = useState<{ id: string; email: string } | null>(null)
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [activeView, setActiveView] = useState<View>('dashboard')
  const [isAddModalOpen, setIsAddModalOpen] = useState(false)
  const [showUpgradeModal, setShowUpgradeModal] = useState(false)

  // Load user data
  useEffect(() => {
    loadUserData()
  }, [])

  const loadUserData = async () => {
    try {
      setLoading(true)
      setError('')

      // Get current user
      const currentUser = await getCurrentUser()
      if (!currentUser) {
        setError('Please sign in to view your dashboard')
        setLoading(false)
        return
      }

      setUser({
        id: currentUser.id,
        email: currentUser.email || ''
      })

      // Load profile and subscriptions in parallel
      const [profileData, subscriptionsData] = await Promise.all([
        getUserProfile(currentUser.id),
        getUserSubscriptions(currentUser.id)
      ])

      setProfile(profileData)
      setSubscriptions(subscriptionsData)
    } catch (err) {
      console.error('Error loading user data:', err)
      setError('Failed to load your data. Please refresh the page.')
    } finally {
      setLoading(false)
    }
  }

  const handleSignOut = async () => {
    await signOut()
    window.location.reload()
  }

  const handleAddClick = () => {
    if (!profile || !canAddSubscription(profile, subscriptions.length)) {
      setShowUpgradeModal(true)
      return
    }
    setIsAddModalOpen(true)
  }

  const handleSubscriptionAdded = () => {
    loadUserData()
  }

  const handleUpgrade = () => {
    if (user) {
      openCheckout(user.id, user.email)
    }
  }

  const monthlySpending = calculateMonthlySpending(subscriptions)
  const activeSubscriptions = subscriptions.filter(s => s.status === 'active')
  const isPro = profile?.plan_type === 'pro'
  const atLimit = !isPro && subscriptions.length >= 2

  // Loading state
  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="w-10 h-10 text-white animate-spin mx-auto mb-4" />
          <p className="text-white/60">Loading your dashboard...</p>
        </div>
      </div>
    )
  }

  // Error state
  if (error) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center p-4">
        <div className="text-center max-w-md">
          <AlertCircle className="w-12 h-12 text-red-400 mx-auto mb-4" />
          <p className="text-white mb-4">{error}</p>
          <button 
            onClick={() => window.location.reload()}
            className="bg-white/10 hover:bg-white/20 text-white px-6 py-3 rounded-xl transition-colors"
          >
            Refresh Page
          </button>
        </div>
      </div>
    )
  }

  // AI Views
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
        <AICancellationAgent 
          userId={user?.id || ''} 
          subscriptions={subscriptions}
        />
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
        <AISmartPausing 
          userId={user?.id || ''}
          subscriptions={subscriptions}
          onSubscriptionUpdate={loadUserData}
        />
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
        <AIDailyBriefing 
          subscriptions={subscriptions}
          monthlySpending={monthlySpending}
        />
      </>
    )
  }

  return (
    <div className="min-h-screen bg-black text-white">
      {/* Header */}
      <header className="glass sticky top-0 z-40 border-b border-white/5">
        <div className="container mx-auto max-w-6xl px-4 flex items-center justify-between py-4">
          <div className="flex items-center gap-3">
            <span className="text-xl font-bold">Pausely</span>
            {isPro && (
              <span className="px-2 py-0.5 rounded-full bg-gradient-to-r from-yellow-500/20 to-orange-500/20 border border-yellow-500/30 text-yellow-400 text-xs font-medium flex items-center gap-1">
                <Crown className="w-3 h-3" />
                Pro
              </span>
            )}
          </div>
          
          <div className="flex items-center gap-4">
            {!isPro && (
              <button
                onClick={handleUpgrade}
                className="hidden sm:flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-yellow-500/20 to-orange-500/20 border border-yellow-500/30 text-yellow-400 text-sm font-medium hover:from-yellow-500/30 hover:to-orange-500/30 transition-colors"
              >
                <Crown className="w-4 h-4" />
                Upgrade to Pro
              </button>
            )}
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

      <main className="container mx-auto max-w-6xl px-4 py-8 pb-24">
        {/* Welcome */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2">
            Welcome back{profile?.full_name ? `, ${profile.full_name}` : ''} 👋
          </h1>
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
              <p className="text-sm text-white/50">AI drafts cancellation emails for you</p>
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
              <p className="text-sm text-white/50">Detect unused subscriptions automatically</p>
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
              <p className="text-sm text-white/50">Morning email with personalized insights</p>
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
              <span>AI optimizing your subscriptions</span>
            </div>
          </div>

          <div className="card">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 rounded-xl bg-green-500/20 flex items-center justify-center">
                <Gift className="w-6 h-6 text-green-400" />
              </div>
              <div>
                <p className="text-sm text-white/60">Active Subscriptions</p>
                <p className="text-2xl font-bold">{activeSubscriptions.length}</p>
              </div>
            </div>
            <div className="text-white/60 text-sm">
              {!isPro && (
                <span className={atLimit ? 'text-orange-400' : ''}>
                  {subscriptions.length}/2 free plan limit
                </span>
              )}
              {isPro && <span>Unlimited with Pro</span>}
            </div>
          </div>
        </div>

        {/* Subscriptions Header */}
        <div className="mb-6 flex items-center justify-between">
          <h2 className="text-xl font-semibold">Your Subscriptions</h2>
          <button 
            onClick={handleAddClick}
            disabled={atLimit && !isPro}
            className="btn-primary text-sm py-2 px-4 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Plus className="w-4 h-4 mr-2" />
            Add New
          </button>
        </div>

        {/* Subscriptions List */}
        {subscriptions.length === 0 ? (
          <div className="card text-center py-16">
            <div className="w-20 h-20 rounded-full bg-white/5 flex items-center justify-center mx-auto mb-6">
              <Plus className="w-10 h-10 text-white/30" />
            </div>
            <h3 className="text-xl font-semibold mb-2">No subscriptions yet</h3>
            <p className="text-white/50 mb-6 max-w-sm mx-auto">
              Add your first subscription to start tracking your spending and discover savings with AI.
            </p>
            <button 
              onClick={() => setIsAddModalOpen(true)}
              className="btn-primary"
            >
              <Plus className="w-5 h-5 mr-2" />
              Add Your First Subscription
            </button>
          </div>
        ) : (
          <div className="space-y-3">
            {subscriptions.map((sub) => (
              <div key={sub.id} className="card flex items-center justify-between group">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center text-lg font-semibold">
                    {sub.name[0]}
                  </div>
                  <div>
                    <p className="font-semibold">{sub.name}</p>
                    <div className="flex items-center gap-2 text-sm">
                      <span className={`
                        px-2 py-0.5 rounded-full text-xs
                        ${sub.status === 'active' ? 'bg-green-500/20 text-green-400' : ''}
                        ${sub.status === 'paused' ? 'bg-orange-500/20 text-orange-400' : ''}
                        ${sub.status === 'cancelled' ? 'bg-red-500/20 text-red-400' : ''}
                      `}>
                        {sub.status}
                      </span>
                      <span className="text-white/40">{sub.category}</span>
                    </div>
                  </div>
                </div>
                
                <div className="flex items-center gap-4">
                  <div className="text-right">
                    <p className="font-semibold">${sub.amount.toFixed(2)}</p>
                    <p className="text-sm text-white/40">/{sub.billing_cycle}</p>
                  </div>
                  <ChevronRight className="w-5 h-5 text-white/40" />
                </div>
              </div>
            ))}
          </div>
        )}

        {/* AI Insight */}
        {subscriptions.length > 0 && (
          <div className="mt-8 card bg-gradient-to-br from-blue-500/10 to-purple-500/10 border-blue-500/20">
            <div className="flex items-start gap-4">
              <div className="w-10 h-10 rounded-xl bg-blue-500/20 flex items-center justify-center flex-shrink-0">
                <Sparkles className="w-5 h-5 text-blue-400" />
              </div>
              <div>
                <h3 className="font-semibold mb-1">💡 AI Insight</h3>
                <p className="text-white/70 text-sm">
                  You're spending ${monthlySpending.toFixed(2)}/month on {activeSubscriptions.length} active subscriptions. 
                  {monthlySpending > 100 
                    ? "That's over $100/month - consider reviewing your subscriptions to find potential savings."
                    : "Great job keeping your subscription spending low!"}
                </p>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Add Subscription Modal */}
      {user && (
        <AddSubscriptionModal
          userId={user.id}
          isOpen={isAddModalOpen}
          onClose={() => setIsAddModalOpen(false)}
          onSuccess={handleSubscriptionAdded}
        />
      )}

      {/* Upgrade Modal */}
      {showUpgradeModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div
            className="absolute inset-0 bg-black/80 backdrop-blur-sm"
            onClick={() => setShowUpgradeModal(false)}
          />
          
          <div className="relative w-full max-w-md bg-[#1a1a2e] rounded-3xl border border-white/10 p-8">
            <button
              onClick={() => setShowUpgradeModal(false)}
              className="absolute top-4 right-4 p-2 hover:bg-white/10 rounded-full"
            >
              <Plus className="w-5 h-5 text-white/60 rotate-45" />
            </button>

            <div className="text-center">
              <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-yellow-500 to-orange-500 flex items-center justify-center mx-auto mb-6">
                <Crown className="w-8 h-8 text-white" />
              </div>
              
              <h2 className="text-2xl font-bold mb-2">Upgrade to Pro</h2>
              <p className="text-white/60 mb-6">
                You've reached the free plan limit of 2 subscriptions.
              </p>

              <div className="bg-white/5 rounded-2xl p-6 mb-6 text-left">
                <p className="text-sm text-white/50 mb-4">Pro includes:</p>
                <ul className="space-y-2">
                  {PLANS.pro.features.slice(0, 5).map((feature, i) => (
                    <li key={i} className="flex items-center gap-2 text-sm">
                      <Sparkles className="w-4 h-4 text-yellow-400" />
                      {feature}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="flex items-baseline justify-center gap-2 mb-6">
                <span className="text-4xl font-bold">${PLANS.pro.price}</span>
                <span className="text-white/50">/month</span>
              </div>

              <button
                onClick={handleUpgrade}
                className="w-full bg-gradient-to-r from-yellow-500 to-orange-500 hover:from-yellow-600 hover:to-orange-600 text-white font-semibold py-4 rounded-xl transition-all"
              >
                Upgrade Now
              </button>
              
              <button
                onClick={() => setShowUpgradeModal(false)}
                className="mt-4 text-sm text-white/50 hover:text-white"
              >
                Maybe later
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
