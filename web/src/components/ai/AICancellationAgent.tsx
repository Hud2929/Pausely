import { useState } from 'react'
import { 
  Bot, 
  ArrowLeft, 
  Send, 
  Loader2, 
  CheckCircle2, 
  MessageSquare,
  Sparkles,
  ChevronRight,
  Copy,
  Check,
  RefreshCw
} from 'lucide-react'
import type { Subscription } from '../../types/subscription'

interface AICancellationAgentProps {
  subscriptions?: Subscription[]
  onBack?: () => void
}

export default function AICancellationAgent({ subscriptions = [], onBack }: AICancellationAgentProps) {
  const [step, setStep] = useState(0)
  const [selectedService, setSelectedService] = useState('')
  const [emailDraft, setEmailDraft] = useState('')
  const [isGenerating, setIsGenerating] = useState(false)
  const [copied, setCopied] = useState(false)

  const generateCancellationEmail = (service: string): string => {
    const templates: Record<string, string> = {
      'Netflix': `Subject: Cancellation Request - Account Termination

Dear Netflix Customer Support,

I am writing to request the immediate cancellation of my Netflix subscription (associated with this email address).

Please confirm the following:
1. My subscription will end at the close of the current billing period
2. I will receive a confirmation email once cancelled
3. My viewing history will remain for 10 months if I choose to return

I appreciate your service but am looking to reduce my monthly expenses. Please process this cancellation without extended retention offers.

Thank you,
[Your Name]`,

      'Spotify': `Subject: Cancel Premium Subscription

Hello Spotify Team,

I would like to cancel my Spotify Premium subscription effective immediately.

My account email: [your-email@example.com]

Please confirm the cancellation and let me know when my Premium access will end. I understand I'll revert to the free tier.

I may return in the future but need to pause my subscription for now.

Best regards,
[Your Name]`,

      'Adobe Creative Cloud': `Subject: Creative Cloud Cancellation Request

Dear Adobe Support,

I need to cancel my Creative Cloud subscription. I understand I may be subject to an early termination fee if I'm on an annual plan.

Account Email: [your-email@example.com]

Please provide:
- Confirmation of cancellation
- Any applicable fees
- Final billing date

I'm happy to complete any exit survey if required.

Sincerely,
[Your Name]`,

      'default': `Subject: Subscription Cancellation Request

Dear ${service} Support Team,

I am writing to formally request the cancellation of my ${service} subscription effective at the end of my current billing cycle.

Account Details:
- Email: [your-email@example.com]
- Username: [if applicable]

Please confirm:
1. The cancellation has been processed
2. My final billing date
3. Any steps I need to take on my end

I appreciate the service but need to make changes to my subscription portfolio. Please honor this cancellation request without extended retention conversations.

Thank you for your assistance.

Best regards,
[Your Name]`
    }

    return templates[service] || templates['default']
  }

  const handleServiceSelect = (service: string) => {
    setSelectedService(service)
    setIsGenerating(true)
    
    setTimeout(() => {
      const email = generateCancellationEmail(service)
      setEmailDraft(email)
      setIsGenerating(false)
      setStep(2)
    }, 1500)
  }

  const handleCopyEmail = () => {
    navigator.clipboard.writeText(emailDraft)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleStartOver = () => {
    setStep(0)
    setSelectedService('')
    setEmailDraft('')
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
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
              <Bot className="w-5 h-5" />
            </div>
            <div className="text-left">
              <h1 className="font-semibold">Cancellation Agent</h1>
              <p className="text-xs text-white/50">AI-Powered</p>
            </div>
          </div>
          
          <div className="w-20" />
        </div>
      </header>

      <main className="container max-w-2xl mx-auto px-4 py-8 pb-32">
        {/* Progress */}
        <div className="flex items-center justify-center gap-2 mb-8">
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className={`h-1.5 rounded-full transition-all ${
                i <= step ? 'w-10 bg-purple-500' : 'w-1.5 bg-white/20'
              }`}
            />
          ))}
        </div>

        {/* Step 0: Introduction */}
        {step === 0 && (
          <div className="space-y-8">
            <div className="text-center space-y-4">
              <div className="w-20 h-20 rounded-2xl bg-gradient-to-br from-purple-500/20 to-pink-500/20 flex items-center justify-center mx-auto">
                <Sparkles className="w-10 h-10 text-purple-400" />
              </div>
              <h2 className="text-2xl font-bold">Cancel Any Subscription</h2>
              <p className="text-white/60 max-w-md mx-auto leading-relaxed">
                I'll draft professional cancellation emails for you. No awkward phone calls, 
                no hassle. Just select the service and I'll handle the rest.
              </p>
            </div>

            <div className="glass rounded-2xl p-6 space-y-4">
              <h3 className="font-medium text-lg">How it works</h3>
              <div className="space-y-4">
                {[
                  { icon: '1', text: 'Select the subscription you want to cancel' },
                  { icon: '2', text: 'AI drafts a professional cancellation email' },
                  { icon: '3', text: 'Copy and send - or let us handle it' }
                ].map((item, i) => (
                  <div key={i} className="flex items-center gap-4">
                    <div className="w-8 h-8 rounded-full bg-purple-500/20 flex items-center justify-center flex-shrink-0">
                      <span className="text-sm font-semibold text-purple-400">{item.icon}</span>
                    </div>
                    <p className="text-white/70">{item.text}</p>
                  </div>
                ))}
              </div>
            </div>

            <button
              onClick={() => setStep(1)}
              className="w-full btn-primary py-4"
            >
              Get Started
              <ChevronRight className="w-5 h-5 ml-2" />
            </button>
          </div>
        )}

        {/* Step 1: Select Service */}
        {step === 1 && (
          <div className="space-y-6">
            <div className="text-center space-y-2">
              <h2 className="text-xl font-bold">Which subscription?</h2>
              <p className="text-white/50">Select the service you want to cancel</p>
            </div>

            {subscriptions.length > 0 ? (
              <div className="space-y-3">
                {subscriptions.map((sub) => (
                  <button
                    key={sub.id}
                    onClick={() => handleServiceSelect(sub.name)}
                    disabled={isGenerating}
                    className="w-full glass rounded-xl p-4 flex items-center justify-between hover:bg-white/5 transition-all"
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center text-lg font-semibold">
                        {sub.name[0]}
                      </div>
                      <div className="text-left">
                        <p className="font-medium">{sub.name}</p>
                        <p className="text-sm text-white/50">${sub.amount}/month</p>
                      </div>
                    </div>
                    <ChevronRight className="w-5 h-5 text-white/30" />
                  </button>
                ))}
              </div>
            ) : (
              <div className="glass rounded-xl p-8 text-center space-y-4">
                <p className="text-white/60">No subscriptions found. Enter the service name manually:</p>
                <div className="flex gap-3">
                  <input
                    type="text"
                    placeholder="e.g., Netflix, Spotify, Gym..."
                    className="input flex-1"
                    onKeyPress={(e) => {
                      if (e.key === 'Enter') {
                        handleServiceSelect((e.target as HTMLInputElement).value)
                      }
                    }}
                  />
                </div>
              </div>
            )}

            <div className="glass rounded-xl p-6">
              <p className="text-sm text-white/50 mb-3">Popular services</p>
              <div className="flex flex-wrap gap-2">
                {['Netflix', 'Spotify', 'Adobe', 'Disney+', 'Hulu', 'Gym'].map((service) => (
                  <button
                    key={service}
                    onClick={() => handleServiceSelect(service)}
                    disabled={isGenerating}
                    className="px-4 py-2 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 text-sm transition-all"
                  >
                    {service}
                  </button>
                ))}
              </div>
            </div>

            {isGenerating && (
              <div className="flex items-center justify-center gap-3 py-8">
                <Loader2 className="w-6 h-6 animate-spin text-purple-400" />
                <span className="text-white/70">Drafting cancellation email...</span>
              </div>
            )}
          </div>
        )}

        {/* Step 2: Email Draft */}
        {step === 2 && emailDraft && (
          <div className="space-y-6">
            <div className="text-center space-y-2">
              <div className="w-12 h-12 rounded-full bg-green-500/20 flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 className="w-6 h-6 text-green-400" />
              </div>
              <h2 className="text-xl font-bold">Email Draft Ready</h2>
              <p className="text-white/50">Copy this email and send it to cancel your {selectedService} subscription</p>
            </div>

            <div className="glass rounded-xl overflow-hidden">
              <div className="bg-white/5 px-4 py-3 border-b border-white/10 flex items-center justify-between">
                <span className="text-sm text-white/50">Cancellation Email</span>
                <button
                  onClick={handleCopyEmail}
                  className="flex items-center gap-2 text-sm text-purple-400 hover:text-purple-300 transition-colors"
                >
                  {copied ? (
                    <>
                      <Check className="w-4 h-4" />
                      Copied!
                    </>
                  ) : (
                    <>
                      <Copy className="w-4 h-4" />
                      Copy
                    </>
                  )}
                </button>
              </div>
              <pre className="p-4 text-sm text-white/80 whitespace-pre-wrap font-mono leading-relaxed max-h-96 overflow-y-auto">
                {emailDraft}
              </pre>
            </div>

            <div className="space-y-3">
              <p className="text-sm text-white/50 text-center">What would you like to do next?</p>
              
              <div className="grid grid-cols-2 gap-3">
                <a
                  href={`mailto:support@${selectedService.toLowerCase().replace(/\s/g, '')}.com?subject=Cancellation Request&body=${encodeURIComponent(emailDraft)}`}
                  className="btn-primary py-3 text-center flex items-center justify-center gap-2"
                >
                  <Send className="w-4 h-4" />
                  Send Email
                </a>
                
                <button
                  onClick={handleStartOver}
                  className="py-3 rounded-full border border-white/20 text-white font-medium hover:bg-white/5 transition-all flex items-center justify-center gap-2"
                >
                  <RefreshCw className="w-4 h-4" />
                  Start Over
                </button>
              </div>
            </div>

            <div className="glass rounded-xl p-4 bg-yellow-500/5 border-yellow-500/20">
              <div className="flex items-start gap-3">
                <MessageSquare className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
                <div className="text-sm text-white/70">
                  <p className="font-medium text-white mb-1">Pro Tip</p>
                  <p>{selectedService} may offer you a discount to stay. If they do, you'll save money! If not, your cancellation will proceed.</p>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
