import { useState } from 'react'
import { 
  Bot, 
  Loader2, 
  CheckCircle2, 
  XCircle, 
  MessageSquare, 
  Sparkles,
  RefreshCw,
  Copy,
  Check
} from 'lucide-react'
import { createCancellationRequest } from '../../lib/database'
import type { Subscription } from '../../types/subscription'

interface AICancellationAgentProps {
  userId: string
  subscriptions: Subscription[]
}

interface CancellationRequest {
  id: string
  serviceName: string
  status: 'drafting' | 'sent' | 'negotiating' | 'cancelled' | 'saved'
  messages: Message[]
  createdAt: Date
}

interface Message {
  id: string
  role: 'ai' | 'user' | 'company'
  content: string
  timestamp: Date
  type?: 'email' | 'chat' | 'suggestion'
}

export default function AICancellationAgent({ userId, subscriptions }: AICancellationAgentProps) {
  const [selectedService, setSelectedService] = useState('')
  const [customService, setCustomService] = useState('')
  const [isProcessing, setIsProcessing] = useState(false)
  const [request, setRequest] = useState<CancellationRequest | null>(null)
  const [copied, setCopied] = useState(false)

  // Get active subscriptions for quick select
  const activeSubscriptions = subscriptions.filter(s => s.status === 'active')

  const generateAICancellation = async () => {
    const service = selectedService || customService
    if (!service) return

    setIsProcessing(true)

    // Simulate AI processing with a realistic delay
    await new Promise(resolve => setTimeout(resolve, 2000))

    const aiRequest: CancellationRequest = {
      id: Date.now().toString(),
      serviceName: service,
      status: 'drafting',
      createdAt: new Date(),
      messages: [
        {
          id: '1',
          role: 'ai',
          content: `I've analyzed ${service}'s cancellation policies. They typically require email or chat support. I'll draft a professional cancellation request that minimizes retention pressure and gets straight to the point.`,
          timestamp: new Date(),
          type: 'suggestion'
        },
        {
          id: '2',
          role: 'ai',
          content: generateCancellationEmail(service),
          timestamp: new Date(),
          type: 'email'
        },
        {
          id: '3',
          role: 'ai',
          content: `Pro tip: ${service} often offers 50% off for 3 months when you try to cancel. I'll monitor their response and negotiate if they offer retention deals.`,
          timestamp: new Date(),
          type: 'suggestion'
        }
      ]
    }

    setRequest(aiRequest)
    setIsProcessing(false)

    // Save to database
    try {
      const matchingSub = subscriptions.find(s => 
        s.name.toLowerCase() === service.toLowerCase()
      )
      
      await createCancellationRequest({
        user_id: userId,
        subscription_id: matchingSub?.id || null,
        service_name: service,
        status: 'drafting',
        email_content: generateCancellationEmail(service),
        company_response: null,
        final_status: null
      })
    } catch (err) {
      console.error('Error saving cancellation request:', err)
    }
  }

  const generateCancellationEmail = (service: string): string => {
    const templates: Record<string, string> = {
      'Netflix': `Subject: Account Cancellation Request

Dear Netflix Support,

I am writing to request the immediate cancellation of my Netflix subscription (associated with this email address).

Please confirm:
1. My subscription will end at the close of the current billing period
2. I will receive a confirmation email once cancelled
3. My viewing history will remain for 10 months if I choose to return

I appreciate your service but am looking to reduce my monthly expenses. Please process this cancellation without retention offers.

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

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const simulateCompanyResponse = async () => {
    if (!request) return

    setIsProcessing(true)
    await new Promise(resolve => setTimeout(resolve, 1500))

    const responses = [
      {
        id: Date.now().toString() + '1',
        role: 'company' as const,
        content: `We're sorry to see you go! As a valued customer, we'd like to offer you 3 months at 50% off ($7.99/month instead of $15.99). Would you like to accept this offer?`,
        timestamp: new Date(),
        type: 'email' as const
      },
      {
        id: Date.now().toString() + '2',
        role: 'ai' as const,
        content: `🎯 RETENTION OFFER DETECTED! They're offering 50% off for 3 months. That's $24 savings. Want me to:\n\n1. Accept the offer (stay subscribed)\n2. Decline and continue cancellation\n3. Counter-offer (ask for 6 months at 50% off)`,
        timestamp: new Date(),
        type: 'suggestion' as const
      }
    ]

    setRequest({
      ...request,
      messages: [...request.messages, ...responses],
      status: 'negotiating'
    })

    setIsProcessing(false)
  }

  const handleResponse = (action: 'accept' | 'decline' | 'counter') => {
    if (!request) return

    let response = ''
    let newStatus: CancellationRequest['status'] = 'negotiating'

    switch (action) {
      case 'accept':
        response = "I'll accept the 50% off offer for 3 months. Please apply this to my account."
        newStatus = 'saved'
        break
      case 'decline':
        response = "I appreciate the offer, but I'd still like to proceed with the cancellation. Please confirm the cancellation."
        newStatus = 'cancelled'
        break
      case 'counter':
        response = "Would you consider extending that offer to 6 months at 50% off? That would make it worth staying."
        break
    }

    setRequest({
      ...request,
      messages: [
        ...request.messages,
        {
          id: Date.now().toString(),
          role: 'user',
          content: response,
          timestamp: new Date(),
          type: 'email'
        }
      ],
      status: newStatus
    })
  }

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-purple-500/10 border border-purple-500/20 mb-6">
            <Sparkles className="w-4 h-4 text-purple-400" />
            <span className="text-sm text-purple-400 font-medium">AI-Powered</span>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-bold mb-4">
            Cancellation
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-purple-400 to-pink-400"> Agent</span>
          </h1>
          
          <p className="text-xl text-white/60 max-w-2xl mx-auto">
            Our AI handles the annoying cancellation process for you. 
            Drafts emails, negotiates retention offers, and tracks everything.
          </p>
        </div>

        {/* Service Selection */}
        {!request && (
          <div className="max-w-2xl mx-auto">
            <div className="bg-white/5 border border-white/10 rounded-3xl p-8 mb-6">
              <h2 className="text-2xl font-semibold mb-6">What do you want to cancel?</h2>
              
              {/* Active Subscriptions Quick Select */}
              {activeSubscriptions.length > 0 && (
                <div className="mb-6">
                  <p className="text-sm text-white/50 mb-3">Your active subscriptions:</p>
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                    {activeSubscriptions.map((sub) => (
                      <button
                        key={sub.id}
                        onClick={() => {
                          setSelectedService(sub.name)
                          setCustomService('')
                        }}
                        className={`p-4 rounded-xl text-sm font-medium transition-all ${
                          selectedService === sub.name
                            ? 'bg-purple-500 text-white'
                            : 'bg-white/5 hover:bg-white/10 text-white/70'
                        }`}
                      >
                        <span className="block font-semibold">{sub.name}</span>
                        <span className="text-xs opacity-70">${sub.amount}/{sub.billing_cycle}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}
              
              <div className="relative">
                <p className="text-sm text-white/50 mb-3">Or enter a custom service:</p>
                <input
                  type="text"
                  value={customService}
                  onChange={(e) => {
                    setCustomService(e.target.value)
                    setSelectedService('')
                  }}
                  placeholder="Type service name..."
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-4 text-white placeholder:text-white/40 focus:outline-none focus:border-purple-500/50"
                />
              </div>
            </div>

            <button
              onClick={generateAICancellation}
              disabled={isProcessing || (!selectedService && !customService)}
              className="w-full bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold py-5 rounded-2xl flex items-center justify-center gap-3 transition-all text-lg"
            >
              {isProcessing ? (
                <>
                  <Loader2 className="w-6 h-6 animate-spin" />
                  AI is analyzing cancellation policies...
                </>
              ) : (
                <>
                  <Bot className="w-6 h-6" />
                  Generate Cancellation Request
                </>
              )}
            </button>
          </div>
        )}

        {/* AI Conversation */}
        {request && (
          <div className="max-w-3xl mx-auto">
            <div className="bg-white/5 border border-white/10 rounded-3xl overflow-hidden">
              {/* Status Bar */}
              <div className="px-6 py-4 bg-white/5 border-b border-white/10 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                    <Bot className="w-5 h-5" />
                  </div>
                  <div>
                    <p className="font-semibold">AI Cancellation Agent</p>
                    <p className="text-sm text-white/50">{request.serviceName}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {request.status === 'drafting' && (
                    <span className="px-3 py-1 rounded-full bg-yellow-500/20 text-yellow-400 text-sm">Drafting</span>
                  )}
                  {request.status === 'negotiating' && (
                    <span className="px-3 py-1 rounded-full bg-blue-500/20 text-blue-400 text-sm">Negotiating</span>
                  )}
                  {request.status === 'saved' && (
                    <span className="px-3 py-1 rounded-full bg-green-500/20 text-green-400 text-sm flex items-center gap-1">
                      <CheckCircle2 className="w-4 h-4" />
                      Money Saved
                    </span>
                  )}
                  {request.status === 'cancelled' && (
                    <span className="px-3 py-1 rounded-full bg-red-500/20 text-red-400 text-sm flex items-center gap-1">
                      <XCircle className="w-4 h-4" />
                      Cancelled
                    </span>
                  )}
                </div>
              </div>

              {/* Messages */}
              <div className="p-6 space-y-6 max-h-[500px] overflow-y-auto">
                {request.messages.map((message) => (
                  <div
                    key={message.id}
                    className={`flex gap-4 ${
                      message.role === 'user' ? 'flex-row-reverse' : ''
                    }`}
                  >
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${
                      message.role === 'ai'
                        ? 'bg-gradient-to-br from-purple-500 to-pink-500'
                        : message.role === 'company'
                        ? 'bg-blue-500'
                        : 'bg-white/10'
                    }`}>
                      {message.role === 'ai' && <Bot className="w-5 h-5" />}
                      {message.role === 'company' && <MessageSquare className="w-5 h-5" />}
                      {message.role === 'user' && <span className="text-sm font-semibold">You</span>}
                    </div>
                    
                    <div className={`flex-1 ${
                      message.role === 'user' ? 'text-right' : ''
                    }`}>
                      {message.type === 'email' && message.role !== 'user' && (
                        <div className="bg-white/5 border border-white/10 rounded-xl p-4 text-left">
                          <pre className="whitespace-pre-wrap text-sm text-white/80 font-mono">{message.content}</pre>
                          <button
                            onClick={() => copyToClipboard(message.content)}
                            className="mt-4 flex items-center gap-2 text-sm text-purple-400 hover:text-purple-300 transition-colors"
                          >
                            {copied ? (
                              <>
                                <Check className="w-4 h-4" />
                                Copied!
                              </>
                            ) : (
                              <>
                                <Copy className="w-4 h-4" />
                                Copy to Clipboard
                              </>
                            )}
                          </button>
                        </div>
                      )}
                      
                      {message.type === 'suggestion' && (
                        <div className="bg-purple-500/10 border border-purple-500/20 rounded-xl p-4">
                          <div className="flex items-center gap-2 mb-2">
                            <Sparkles className="w-4 h-4 text-purple-400" />
                            <span className="text-sm font-medium text-purple-400">AI Insight</span>
                          </div>
                          <p className="text-white/80 whitespace-pre-line">{message.content}</p>
                        </div>
                      )}
                      
                      {message.role === 'user' && (
                        <div className="bg-white/10 rounded-xl p-4 inline-block text-left">
                          <p className="text-white">{message.content}</p>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
                
                {isProcessing && (
                  <div className="flex items-center gap-3 text-white/50">
                    <Loader2 className="w-5 h-5 animate-spin" />
                    <span>AI is analyzing response...</span>
                  </div>
                )}
              </div>

              {/* Action Buttons */}
              {request.status === 'drafting' && (
                <div className="px-6 py-4 bg-white/5 border-t border-white/10 flex gap-3">
                  <button
                    onClick={simulateCompanyResponse}
                    className="flex-1 bg-white/10 hover:bg-white/15 py-3 rounded-xl font-medium transition-colors flex items-center justify-center gap-2"
                  >
                    Simulate Company Response
                  </button>
                </div>
              )}

              {request.status === 'negotiating' && (
                <div className="px-6 py-4 bg-white/5 border-t border-white/10">
                  <p className="text-sm text-white/60 mb-4">How would you like to respond?</p>
                  <div className="grid grid-cols-3 gap-3">
                    <button
                      onClick={() => handleResponse('accept')}
                      className="bg-green-500/20 hover:bg-green-500/30 border border-green-500/30 py-3 rounded-xl font-medium text-green-400 transition-colors"
                    >
                      Accept Offer
                    </button>
                    <button
                      onClick={() => handleResponse('decline')}
                      className="bg-red-500/20 hover:bg-red-500/30 border border-red-500/30 py-3 rounded-xl font-medium text-red-400 transition-colors"
                    >
                      Decline & Cancel
                    </button>
                    <button
                      onClick={() => handleResponse('counter')}
                      className="bg-purple-500/20 hover:bg-purple-500/30 border border-purple-500/30 py-3 rounded-xl font-medium text-purple-400 transition-colors"
                    >
                      Counter Offer
                    </button>
                  </div>
                </div>
              )}
            </div>

            <button
              onClick={() => {
                setRequest(null)
                setSelectedService('')
                setCustomService('')
              }}
              className="mt-6 w-full py-4 rounded-2xl border border-white/10 hover:bg-white/5 transition-colors flex items-center justify-center gap-2"
            >
              <RefreshCw className="w-5 h-5" />
              Start New Cancellation
            </button>
          </div>
        )}

        {/* Features */}
        {!request && (
          <div className="mt-16 grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
            {[
              {
                icon: Bot,
                title: 'AI Drafts Emails',
                description: 'Professional cancellation requests tailored to each service'
              },
              {
                icon: MessageSquare,
                title: 'Negotiates For You',
                description: 'Handles retention offers and counters automatically'
              },
              {
                icon: CheckCircle2,
                title: 'Tracks Everything',
                description: 'Monitors responses and confirms cancellations'
              }
            ].map((feature, i) => (
              <div key={i} className="bg-white/5 border border-white/10 rounded-2xl p-6">
                <feature.icon className="w-8 h-8 text-purple-400 mb-4" />
                <h3 className="font-semibold mb-2">{feature.title}</h3>
                <p className="text-white/60 text-sm">{feature.description}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
