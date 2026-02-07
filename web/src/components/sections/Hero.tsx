import { useEffect, useRef, useState } from 'react'
import { ArrowRight, Sparkles, Wallet, Clock } from 'lucide-react'

export default function Hero() {
  const heroRef = useRef<HTMLDivElement>(null)
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 })

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (heroRef.current) {
        const rect = heroRef.current.getBoundingClientRect()
        setMousePosition({
          x: (e.clientX - rect.left) / rect.width,
          y: (e.clientY - rect.top) / rect.height,
        })
      }
    }

    window.addEventListener('mousemove', handleMouseMove)
    return () => window.removeEventListener('mousemove', handleMouseMove)
  }, [])

  const scrollToFeatures = () => {
    const element = document.querySelector('#features')
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' })
    }
  }

  const scrollToCTA = () => {
    const element = document.querySelector('#cta')
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' })
    }
  }

  return (
    <section
      ref={heroRef}
      className="relative min-h-screen flex items-center justify-center overflow-hidden"
      style={{
        background: `radial-gradient(ellipse at ${mousePosition.x * 100}% ${mousePosition.y * 100}%, rgba(0, 122, 255, 0.15) 0%, transparent 50%),
                    radial-gradient(ellipse at 50% 100%, rgba(175, 82, 222, 0.1) 0%, transparent 50%),
                    #000000`,
      }}
    >
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-blue-500/10 rounded-full blur-3xl animate-float" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl animate-float" style={{ animationDelay: '1.5s' }} />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-gradient-to-r from-blue-500/5 to-purple-500/5 rounded-full blur-3xl" />
      </div>

      {/* Grid Pattern */}
      <div 
        className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage: `linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px),
                           linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)`,
          backgroundSize: '60px 60px',
        }}
      />

      <div className="container relative z-10 pt-24">
        {/* Badge */}
        <div className="flex justify-center mb-8 animate-fadeIn">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass">
            <Sparkles className="w-4 h-4 text-blue-400" />
            <span className="text-sm font-medium text-white/80">Now with AI-powered insights</span>
          </div>
        </div>

        {/* Main Headline */}
        <div className="text-center max-w-5xl mx-auto">
          <h1 className="headline-xl mb-6 animate-fadeInUp">
            <span className="block text-white">Stop overpaying for</span>
            <span className="block gradient-text">subscriptions you don't use.</span>
          </h1>

          <p className="body-large max-w-2xl mx-auto mb-10 animate-fadeInUp" style={{ animationDelay: '0.1s' }}>
            Pausely analyzes your subscriptions, finds free alternatives you already have access to, 
            and helps you pause instead of cancel. The average user saves $127/month.
          </p>

          {/* CTA Buttons */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16 animate-fadeInUp" style={{ animationDelay: '0.2s' }}>
            <button
              onClick={scrollToCTA}
              className="btn-primary text-lg px-8 py-4 group"
            >
              Start Saving Today
              <ArrowRight className="w-5 h-5 ml-2 transition-transform group-hover:translate-x-1" />
            </button>
            <button
              onClick={scrollToFeatures}
              className="btn-secondary text-lg px-8 py-4"
            >
              See How It Works
            </button>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-3 gap-8 max-w-3xl mx-auto animate-fadeInUp" style={{ animationDelay: '0.3s' }}>
            <div className="text-center">
              <div className="flex items-center justify-center mb-2">
                <Wallet className="w-6 h-6 text-green-400" />
              </div>
              <p className="text-3xl font-bold text-white">$127</p>
              <p className="text-sm text-white/60">Avg monthly savings</p>
            </div>
            <div className="text-center">
              <div className="flex items-center justify-center mb-2">
                <Clock className="w-6 h-6 text-blue-400" />
              </div>
              <p className="text-3xl font-bold text-white">5 min</p>
              <p className="text-sm text-white/60">To get started</p>
            </div>
            <div className="text-center">
              <div className="flex items-center justify-center mb-2">
                <Sparkles className="w-6 h-6 text-purple-400" />
              </div>
              <p className="text-3xl font-bold text-white">10K+</p>
              <p className="text-sm text-white/60">Happy users</p>
            </div>
          </div>
        </div>

        {/* App Preview */}
        <div className="mt-20 relative animate-fadeInUp" style={{ animationDelay: '0.4s' }}>
          <div className="relative max-w-4xl mx-auto">
            {/* Glow Effect */}
            <div className="absolute -inset-4 bg-gradient-to-r from-blue-500/20 via-purple-500/20 to-pink-500/20 rounded-3xl blur-2xl" />
            
            {/* Phone Frame */}
            <div className="relative glass rounded-[40px] p-3 shadow-2xl">
              <div className="bg-[#1c1c1e] rounded-[32px] overflow-hidden">
                {/* App Header */}
                <div className="px-6 py-4 border-b border-white/5">
                  <div className="flex items-center justify-between">
                    <span className="text-lg font-semibold">Pausely</span>
                    <div className="flex gap-2">
                      <div className="w-8 h-8 rounded-full bg-white/10" />
                    </div>
                  </div>
                </div>

                {/* App Content Preview */}
                <div className="p-6">
                  <div className="mb-6">
                    <p className="text-white/60 text-sm mb-1">Monthly Spending</p>
                    <p className="text-4xl font-bold">$247.00</p>
                    <div className="flex items-center gap-2 mt-2">
                      <span className="text-green-400 text-sm">↓ $89 saved this month</span>
                    </div>
                  </div>

                  <div className="space-y-3">
                    {[
                      { name: 'Netflix', amount: '$15.99', change: '↓ 40%', color: 'text-red-400' },
                      { name: 'Spotify', amount: '$9.99', change: '↓ 20%', color: 'text-green-400' },
                      { name: 'Gym Membership', amount: '$49.99', change: 'Paused', color: 'text-orange-400' },
                    ].map((sub, i) => (
                      <div key={i} className="flex items-center justify-between p-4 rounded-xl bg-white/5">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-lg bg-white/10 flex items-center justify-center">
                            {sub.name[0]}
                          </div>
                          <span className="font-medium">{sub.name}</span>
                        </div>
                        <div className="text-right">
                          <p className="font-semibold">{sub.amount}</p>
                          <p className={`text-sm ${sub.color}`}>{sub.change}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>

            {/* Floating Cards */}
            <div className="absolute -left-4 top-1/4 glass rounded-xl p-4 animate-float hidden lg:block">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-green-500/20 flex items-center justify-center">
                  <span className="text-green-400 text-lg">💰</span>
                </div>
                <div>
                  <p className="text-sm font-medium">Free Perk Found!</p>
                  <p className="text-xs text-white/60">Chase → DashPass</p>
                </div>
              </div>
            </div>

            <div className="absolute -right-4 top-1/3 glass rounded-xl p-4 animate-float hidden lg:block" style={{ animationDelay: '1s' }}>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-blue-500/20 flex items-center justify-center">
                  <span className="text-blue-400 text-lg">⏸️</span>
                </div>
                <div>
                  <p className="text-sm font-medium">Subscription Paused</p>
                  <p className="text-xs text-white/60">Netflix for 3 months</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
