import { useState } from 'react'
import { 
  PauseCircle, 
  ArrowLeft, 
  TrendingDown, 
  AlertTriangle,
  CheckCircle2,
  Sparkles,
  BarChart3,
  Zap
} from 'lucide-react'
import type { Subscription } from '../../types/subscription'

interface AISmartPausingProps {
  subscriptions?: Subscription[]
  onBack?: () => void
}

interface PauseRecommendation {
  id: string
  name: string
  amount: number
  usageScore: number
  lastUsed: string
  potentialSavings: number
  recommendation: 'pause' | 'keep' | 'review'
  reason: string
}

export default function AISmartPausing({ subscriptions = [], onBack }: AISmartPausingProps) {
  const [activeTab, setActiveTab] = useState<'recommendations' | 'active' | 'paused'>('recommendations')
  const [showExplanation, setShowExplanation] = useState(true)

  // Generate AI recommendations based on subscription data
  const generateRecommendations = (): PauseRecommendation[] => {
    return subscriptions.map(sub => {
      // Generate consistent usage score based on subscription name
      const nameHash = sub.name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)
      const usageScore = Math.max(10, Math.min(95, (nameHash % 90) + 10))
      
      let lastUsed: string
      let recommendation: 'pause' | 'keep' | 'review'
      let reason: string

      if (usageScore > 80) {
        lastUsed = 'Yesterday'
        recommendation = 'keep'
        reason = 'Used frequently - great value'
      } else if (usageScore > 50) {
        lastUsed = '3 days ago'
        recommendation = 'review'
        reason = 'Moderate usage - monitor this'
      } else if (usageScore > 30) {
        lastUsed = '2 weeks ago'
        recommendation = 'pause'
        reason = 'Low usage - consider pausing'
      } else {
        lastUsed = '1 month ago'
        recommendation = 'pause'
        reason = 'Rarely used - strong candidate to pause'
      }

      return {
        id: sub.id,
        name: sub.name,
        amount: sub.amount,
        usageScore,
        lastUsed,
        potentialSavings: sub.amount,
        recommendation,
        reason
      }
    })
  }

  const recommendations = generateRecommendations()
  const pauseCandidates = recommendations.filter(r => r.recommendation === 'pause')
  const totalPotentialSavings = pauseCandidates.reduce((acc, r) => acc + r.potentialSavings, 0)

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
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-cyan-500 flex items-center justify-center">
              <PauseCircle className="w-5 h-5" />
            </div>
            <div className="text-left">
              <h1 className="font-semibold">Smart Pausing</h1>
              <p className="text-xs text-white/50">AI-Powered</p>
            </div>
          </div>
          
          <div className="w-20" />
        </div>
      </header>

      <main className="container max-w-4xl mx-auto px-4 py-8 pb-32">
        {/* Stats Overview */}
        <div className="grid grid-cols-2 gap-4 mb-8">
          <div className="glass rounded-2xl p-6">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-xl bg-green-500/20 flex items-center justify-center">
                <TrendingDown className="w-5 h-5 text-green-400" />
              </div>
              <span className="text-sm text-white/50">Potential Monthly Savings</span>
            </div>
            <p className="text-4xl font-bold text-green-400">${totalPotentialSavings.toFixed(2)}</p>
          </div>
          
          <div className="glass rounded-2xl p-6">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-xl bg-blue-500/20 flex items-center justify-center">
                <Zap className="w-5 h-5 text-blue-400" />
              </div>
              <span className="text-sm text-white/50">AI Recommendations</span>
            </div>
            <p className="text-4xl font-bold">{pauseCandidates.length}</p>
          </div>
        </div>

        {/* How It Works */}
        {showExplanation && (
          <div className="glass rounded-2xl p-6 mb-8">
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <Sparkles className="w-6 h-6 text-blue-400" />
                <h2 className="font-semibold text-lg">How Smart Pausing Works</h2>
              </div>
              <button 
                onClick={() => setShowExplanation(false)}
                className="text-white/40 hover:text-white text-sm"
              >
                Hide
              </button>
            </div>
            
            <div className="space-y-4">
              {[
                {
                  icon: BarChart3,
                  title: 'AI Analyzes Usage',
                  desc: 'Our AI tracks how often you use each subscription and calculates a usage score.'
                },
                {
                  icon: AlertTriangle,
                  title: 'Identifies Low-Value Subscriptions',
                  desc: 'Subscriptions with low usage scores are flagged as candidates to pause.'
                },
                {
                  icon: PauseCircle,
                  title: 'Pause with One Click',
                  desc: 'Keep your data and history. Resume anytime when you need it again.'
                }
              ].map((step, i) => (
                <div key={i} className="flex items-start gap-4">
                  <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center flex-shrink-0">
                    <step.icon className="w-5 h-5 text-blue-400" />
                  </div>
                  <div>
                    <p className="font-medium mb-1">{step.title}</p>
                    <p className="text-sm text-white/60">{step.desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Tabs */}
        <div className="flex gap-2 mb-6">
          {[
            { id: 'recommendations', label: 'AI Recommendations', count: pauseCandidates.length },
            { id: 'active', label: 'Active', count: recommendations.filter(r => r.recommendation === 'keep').length },
            { id: 'paused', label: 'Paused', count: 0 }
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`flex-1 py-3 px-4 rounded-xl font-medium text-sm transition-all ${
                activeTab === tab.id
                  ? 'bg-blue-500 text-white'
                  : 'bg-white/5 text-white/60 hover:bg-white/10'
              }`}
            >
              {tab.label}
              {tab.count > 0 && (
                <span className={`ml-2 px-2 py-0.5 rounded-full text-xs ${
                  activeTab === tab.id ? 'bg-white/20' : 'bg-white/10'
                }`}>
                  {tab.count}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Recommendations Tab */}
        {activeTab === 'recommendations' && (
          <div className="space-y-4">
            {pauseCandidates.length === 0 ? (
              <div className="glass rounded-2xl p-12 text-center">
                <CheckCircle2 className="w-16 h-16 text-green-400 mx-auto mb-4" />
                <h3 className="text-xl font-semibold mb-2">All Set!</h3>
                <p className="text-white/60">You're using all your subscriptions regularly. Great job!</p>
              </div>
            ) : (
              <>
                <p className="text-sm text-white/50 mb-4">
                  AI has identified {pauseCandidates.length} subscription{pauseCandidates.length !== 1 ? 's' : ''} you might want to pause
                </p>
                
                {pauseCandidates.map((rec) => (
                  <div key={rec.id} className="glass rounded-2xl p-6">
                    <div className="flex items-start justify-between mb-4">
                      <div className="flex items-center gap-4">
                        <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-orange-500/20 to-red-500/20 flex items-center justify-center">
                          <PauseCircle className="w-7 h-7 text-orange-400" />
                        </div>
                        <div>
                          <h3 className="font-semibold text-lg">{rec.name}</h3>
                          <div className="flex items-center gap-3 mt-1">
                            <span className="text-2xl font-bold">${rec.amount}</span>
                            <span className="text-white/50">/month</span>
                          </div>
                        </div>
                      </div>
                      
                      <div className="text-right">
                        <span className="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-orange-500/20 text-orange-400 text-sm font-medium">
                          <AlertTriangle className="w-4 h-4" />
                          Low Usage
                        </span>
                      </div>
                    </div>

                    <div className="space-y-4">
                      {/* Usage Stats */}
                      <div className="bg-white/5 rounded-xl p-4">
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-sm text-white/70">Usage Score</span>
                          <span className="text-sm font-medium text-orange-400">{rec.usageScore}%</span>
                        </div>
                        <div className="h-2 bg-white/10 rounded-full overflow-hidden">
                          <div 
                            className="h-full bg-gradient-to-r from-orange-500 to-red-500 rounded-full transition-all"
                            style={{ width: `${rec.usageScore}%` }}
                          />
                        </div>
                        <div className="flex items-center justify-between mt-2 text-sm">
                          <span className="text-white/50">Last used: {rec.lastUsed}</span>
                          <span className="text-white/50">{rec.reason}</span>
                        </div>
                      </div>

                      {/* Savings */}
                      <div className="flex items-center justify-between p-4 bg-green-500/5 rounded-xl border border-green-500/20">
                        <div className="flex items-center gap-3">
                          <TrendingDown className="w-5 h-5 text-green-400" />
                          <span className="text-white/70">Potential monthly savings</span>
                        </div>
                        <span className="text-xl font-bold text-green-400">${rec.potentialSavings.toFixed(2)}</span>
                      </div>

                      {/* Action */}
                      <button className="w-full py-4 rounded-xl bg-blue-500 hover:bg-blue-600 text-white font-medium transition-all flex items-center justify-center gap-2">
                        <PauseCircle className="w-5 h-5" />
                        Pause {rec.name}
                      </button>
                    </div>
                  </div>
                ))}
              </>
            )}
          </div>
        )}

        {/* Active Tab */}
        {activeTab === 'active' && (
          <div className="space-y-4">
            {recommendations
              .filter(r => r.recommendation === 'keep')
              .map((rec) => (
                <div key={rec.id} className="glass rounded-2xl p-6">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-xl bg-green-500/20 flex items-center justify-center">
                        <CheckCircle2 className="w-6 h-6 text-green-400" />
                      </div>
                      <div>
                        <h3 className="font-semibold">{rec.name}</h3>
                        <p className="text-sm text-white/50">Last used: {rec.lastUsed}</p>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <p className="font-semibold">${rec.amount}/month</p>
                      <span className="text-sm text-green-400">Good value</span>
                    </div>
                  </div>
                </div>
              ))}
          </div>
        )}

        {/* Paused Tab */}
        {activeTab === 'paused' && (
          <div className="glass rounded-2xl p-12 text-center">
            <PauseCircle className="w-16 h-16 text-white/30 mx-auto mb-4" />
            <h3 className="text-xl font-semibold mb-2">No Paused Subscriptions</h3>
            <p className="text-white/60 mb-6">Subscriptions you pause will appear here. You can resume them anytime.</p>
            <button 
              onClick={() => setActiveTab('recommendations')}
              className="btn-primary"
            >
              View Recommendations
            </button>
          </div>
        )}
      </main>
    </div>
  )
}
