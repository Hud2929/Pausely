import { useState, useRef, useEffect } from 'react'
import { MessageCircle, X, Send, Bot, Sparkles } from 'lucide-react'

interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  timestamp: Date
}

const KNOWLEDGE_BASE = {
  greeting: [
    "Hi! I'm Pause It Agent, your Pausely assistant. How can I help you today?",
    "Hey there! I'm here to help you save money on subscriptions. What would you like to know?",
    "Hello! Ready to optimize your subscriptions? Ask me anything!"
  ],
  pricing: [
    "Pausely has two plans:\n\n**Free Plan** - Track up to 2 subscriptions with basic insights\n\n**Pro Plan** - $4.99/month or $49.99/year with unlimited subscriptions and all AI features. You can switch between USD and CAD!",
    "Our Pro plan is $4.99 USD/month or $6.83 CAD/month. Yearly saves you about $10-12! Plus you get a 7-day free trial."
  ],
  features: [
    "Pausely offers three powerful AI features:\n\n🤖 **AI Cancellation Agent** - Drafts cancellation emails for you\n\n⏸️ **AI Smart Pausing** - Detects unused subscriptions\n\n📧 **AI Daily Briefing** - Morning insights on your spending",
    "With Pausely Pro, you get:\n• Unlimited subscription tracking\n• AI-powered insights\n• Cancellation assistance\n• Smart pausing recommendations\n• Daily spending briefings\n• Priority support"
  ],
  how_it_works: [
    "Using Pausely is simple:\n\n1. **Add** your subscriptions manually\n2. **Analyze** - Our AI reviews your subscriptions\n3. **Optimize** - Find free perks and unused services\n4. **Save** - Pause or cancel with AI help",
    "Just sign up, add your subscriptions, and let our AI do the hard work. You'll see savings opportunities immediately!"
  ],
  privacy: [
    "Your privacy is our priority!\n\n• We don't connect to your bank accounts\n• You manually add subscriptions\n• Your data is encrypted\n• We never sell your information",
    "Unlike other apps, Pausely is privacy-first. No bank connections needed - you control what you share."
  ],
  savings: [
    "Our users save an average of $127/month!\n\nThe AI finds:\n• Forgotten subscriptions\n• Free perks you already have\n• Services you don't use\n• Better pricing options",
    "Most users find 3-5 subscriptions they forgot about, plus $50-100 in free perks they didn't know they had!"
  ],
  trial: [
    "Yes! We offer a 7-day free trial for Pro. No credit card required to start.",
    "Start with our 7-day free trial. If you love it (we think you will!), you can upgrade to Pro."
  ],
  support: [
    "Pro users get priority support. Free users can email us anytime at support@pausely.pro",
    "Need help? Pro users get priority chat support. Everyone can reach us at support@pausely.pro"
  ],
  fallback: [
    "I'm not sure I understand. Try asking about:\n• Pricing\n• Features\n• How it works\n• Privacy\n• Savings",
    "Hmm, I don't have an answer for that yet. Ask me about pricing, features, or how Pausely works!",
    "I'm still learning! Ask me about our pricing plans, AI features, or privacy policy."
  ]
}

function getResponse(input: string): string {
  const lower = input.toLowerCase()
  
  // Pricing questions
  if (lower.includes('price') || lower.includes('cost') || lower.includes('how much') || lower.includes('$') || lower.includes('plan') || lower.includes('usd') || lower.includes('cad')) {
    return randomResponse(KNOWLEDGE_BASE.pricing)
  }
  
  // Feature questions
  if (lower.includes('feature') || lower.includes('ai') || lower.includes('what do you do') || lower.includes('how does it work') || lower.includes('cancellation') || lower.includes('pause')) {
    return randomResponse(KNOWLEDGE_BASE.features)
  }
  
  // How it works
  if (lower.includes('start') || lower.includes('begin') || lower.includes('setup') || lower.includes('use') || lower.includes('work')) {
    return randomResponse(KNOWLEDGE_BASE.how_it_works)
  }
  
  // Privacy
  if (lower.includes('privacy') || lower.includes('safe') || lower.includes('secure') || lower.includes('bank') || lower.includes('data')) {
    return randomResponse(KNOWLEDGE_BASE.privacy)
  }
  
  // Savings
  if (lower.includes('save') || lower.includes('money') || lower.includes('spending') || lower.includes('how much can')) {
    return randomResponse(KNOWLEDGE_BASE.savings)
  }
  
  // Trial
  if (lower.includes('trial') || lower.includes('free') || lower.includes('test') || lower.includes('try')) {
    return randomResponse(KNOWLEDGE_BASE.trial)
  }
  
  // Support
  if (lower.includes('help') || lower.includes('support') || lower.includes('contact') || lower.includes('question')) {
    return randomResponse(KNOWLEDGE_BASE.support)
  }
  
  // Greetings
  if (lower.includes('hi') || lower.includes('hello') || lower.includes('hey') || lower.includes('sup')) {
    return randomResponse(KNOWLEDGE_BASE.greeting)
  }
  
  // Fallback
  return randomResponse(KNOWLEDGE_BASE.fallback)
}

function randomResponse(responses: string[]): string {
  return responses[Math.floor(Math.random() * responses.length)]
}

export default function Chatbot() {
  const [isOpen, setIsOpen] = useState(false)
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [isTyping, setIsTyping] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  // Focus input when opened
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 100)
    }
  }, [isOpen])

  // Initial greeting
  useEffect(() => {
    if (isOpen && messages.length === 0) {
      setTimeout(() => {
        addMessage('assistant', randomResponse(KNOWLEDGE_BASE.greeting))
      }, 500)
    }
  }, [isOpen])

  const addMessage = (role: 'user' | 'assistant', content: string) => {
    setMessages(prev => [...prev, {
      id: Date.now().toString(),
      role,
      content,
      timestamp: new Date()
    }])
  }

  const handleSend = async () => {
    if (!input.trim()) return

    const userMessage = input.trim()
    addMessage('user', userMessage)
    setInput('')
    setIsTyping(true)

    // Simulate AI thinking time
    setTimeout(() => {
      const response = getResponse(userMessage)
      addMessage('assistant', response)
      setIsTyping(false)
    }, 800 + Math.random() * 400)
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  const formatMessage = (content: string) => {
    return content.split('\n').map((line, i) => (
      <span key={i}>
        {line.includes('**') ? (
          <>
            {line.split('**').map((part, j) => 
              j % 2 === 1 ? <strong key={j} className="text-white">{part}</strong> : part
            )}
          </>
        ) : line}
        {i < content.split('\n').length - 1 && <br />}
      </span>
    ))
  }

  return (
    <>
      {/* Floating Button */}
      <button
        onClick={() => setIsOpen(true)}
        className={`fixed bottom-6 right-6 z-50 flex items-center gap-2 px-4 py-3 rounded-full bg-gradient-to-r from-blue-500 to-purple-500 text-white font-medium shadow-lg shadow-blue-500/25 hover:shadow-xl hover:shadow-blue-500/30 transition-all ${
          isOpen ? 'scale-0 opacity-0' : 'scale-100 opacity-100'
        }`}
      >
        <MessageCircle className="w-5 h-5" />
        <span className="hidden sm:inline">Ask Pause It Agent</span>
      </button>

      {/* Chat Window */}
      <div
        className={`fixed bottom-6 right-6 z-50 w-full max-w-sm bg-[#0c0c0e] rounded-3xl border border-white/10 shadow-2xl overflow-hidden transition-all duration-300 ${
          isOpen 
            ? 'scale-100 opacity-100 translate-y-0' 
            : 'scale-95 opacity-0 translate-y-4 pointer-events-none'
        }`}
        style={{ height: isOpen ? '500px' : '0' }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 bg-gradient-to-r from-blue-500/20 to-purple-500/20 border-b border-white/10">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center">
              <Bot className="w-5 h-5 text-white" />
            </div>
            <div>
              <h3 className="font-semibold text-sm">Pause It Agent</h3>
              <div className="flex items-center gap-1 text-xs text-white/50">
                <Sparkles className="w-3 h-3" />
                <span>AI Assistant</span>
              </div>
            </div>
          </div>
          <button
            onClick={() => setIsOpen(false)}
            className="p-2 hover:bg-white/10 rounded-full transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4" style={{ height: 'calc(100% - 130px)' }}>
          {messages.map((message) => (
            <div
              key={message.id}
              className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-[85%] px-4 py-3 rounded-2xl text-sm leading-relaxed ${
                  message.role === 'user'
                    ? 'bg-blue-500 text-white'
                    : 'bg-white/10 text-white/90'
                }`}
              >
                {formatMessage(message.content)}
              </div>
            </div>
          ))}
          
          {isTyping && (
            <div className="flex justify-start">
              <div className="bg-white/10 px-4 py-3 rounded-2xl flex items-center gap-1">
                <span className="w-2 h-2 bg-white/50 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                <span className="w-2 h-2 bg-white/50 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                <span className="w-2 h-2 bg-white/50 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
              </div>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Input */}
        <div className="absolute bottom-0 left-0 right-0 p-4 bg-[#0c0c0e] border-t border-white/10">
          <div className="flex items-center gap-2">
            <input
              ref={inputRef}
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="Ask me anything..."
              className="flex-1 bg-white/5 border border-white/10 rounded-full px-4 py-2.5 text-sm text-white placeholder:text-white/40 focus:outline-none focus:border-white/30"
            />
            <button
              onClick={handleSend}
              disabled={!input.trim() || isTyping}
              className="p-2.5 bg-blue-500 hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed rounded-full transition-colors"
            >
              <Send className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </>
  )
}
