import { useEffect, useRef, useState } from 'react'
import { ArrowRight, Sparkles, Wallet, Clock, Users } from 'lucide-react'

export default function Hero() {
  const heroRef = useRef<HTMLDivElement>(null)
  const [mousePosition, setMousePosition] = useState({ x: 0.5, y: 0.5 })

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
    document.querySelector('#features')?.scrollIntoView({ behavior: 'smooth' })
  }

  const scrollToCTA = () => {
    document.querySelector('#cta')?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section
      ref={heroRef}
      className="relative min-h-screen flex items-center justify-center overflow-hidden pt-24 pb-16"
      style={{
        background: `radial-gradient(ellipse at ${mousePosition.x * 100}% ${mousePosition.y * 100}%, rgba(0, 122, 255, 0.12) 0%, transparent 50%),
                    radial-gradient(ellipse at 50% 100%, rgba(175, 82, 222, 0.08) 0%, transparent 50%),
                    #000000`,
      }}
    >
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-[20%] left-[15%] w-[500px] h-[500px] bg-blue-500/8 rounded-full blur-3xl animate-float" />
        <div className="absolute bottom-[20%] right-[15%] w-[500px] h-[500px] bg-purple-500/8 rounded-full blur-3xl animate-float" style={{ animationDelay: '2s' }} />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[1000px] h-[1000px] bg-gradient-to-r from-blue-500/5 to-purple-500/5 rounded-full blur-3xl" />
      </div>

      <div className="container relative z-10">
        <div className="max-w-6xl mx-auto">
          {/* Badge */}
          <div className="flex justify-center mb-10 animate-fadeIn">
            <div className="inline-flex items-center gap-2.5 px-5 py-2.5 rounded-full glass">
              <Sparkles className="w-4 h-4 text-blue-400" />
              <span className="text-sm font-medium text-white/90">Now with AI-powered insights</span>
            </div>
          </div>

          {/* Main Headline */}
          <div className="text-center mb-12">
            <h1 className="headline-xl mb-8 animate-fadeInUp">
              <span className="block text-white mb-2">Stop overpaying for</span>
              <span className="block gradient-text">subscriptions you don't use.</span>
            </h1>

            <p className="body-large max-w-2xl mx-auto mb-12 animate-fadeInUp" style={{ animationDelay: '0.1s' }}>
              Pausely analyzes your subscriptions, finds free alternatives you already have access to, 
              and helps you pause instead of cancel. The average user saves $127/month.
            </p>

            {/* CTA Buttons */}
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-20 animate-fadeInUp" style={{ animationDelay: '0.2s' }}>
              <button
                onClick={scrollToCTA}
                className="btn-primary text-lg px-10 py-4 group"
              >
                Start Saving Today
                <ArrowRight className="w-5 h-5 ml-2 transition-transform group-hover:translate-x-1" />
              </button>
              <button
                onClick={scrollToFeatures}
                className="btn-secondary text-lg px-10 py-4"
              >
                See How It Works
              </button>
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-3 gap-12 max-w-4xl mx-auto mb-20 animate-fadeInUp" style={{ animationDelay: '0.3s' }}>
            <div className="text-center">
              <div className="flex items-center justify-center mb-4 w-14 h-14 mx-auto rounded-2xl bg-green-500/10">
                <Wallet className="w-7 h-7 text-green-400" />
              </div>
              <p className="text-4xl md:text-5xl font-bold text-white mb-2">$127</p>
              <p className="text-base text-white/60">Avg monthly savings</p>
            </div>
            
            <div className="text-center">
              <div className="flex items-center justify-center mb-4 w-14 h-14 mx-auto rounded-2xl bg-blue-500/10">
                <Clock className="w-7 h-7 text-blue-400" />
              </div>
              <p className="text-4xl md:text-5xl font-bold text-white mb-2">5 min</p>
              <p className="text-base text-white/60">To get started</p>
            </div>
            
            <div className="text-center">
              <div className="flex items-center justify-center mb-4 w-14 h-14 mx-auto rounded-2xl bg-purple-500/10">
                <Users className="w-7 h-7 text-purple-400" />
              </div>
              <p className="text-4xl md:text-5xl font-bold text-white mb-2">10K+</p>
              <p className="text-base text-white/60">Happy users</p>
            </div>
          </div>
        </div>

        {/* App Preview */}
        <div className="relative max-w-5xl mx-auto animate-fadeInUp" style={{ animationDelay: '0.4s' }}>
          {/* Glow Effect */}
          <div className="absolute -inset-8 bg-gradient-to-r from-blue-500/15 via-purple-500/15 to-pink-500/15 rounded-[48px] blur-3xl opacity-60" />
          
          {/* Phone Frame */}
          <div className="relative glass rounded-[44px] p-4 shadow-2xl max-w-2xl mx-auto">
            <div className="bg-[#1c1c1e] rounded-[36px] overflow-hidden">
              {/* App Header */}
              <div className="px-8 py-5 border-b border-white/5 flex items-center justify-between">
                <span className="text-xl font-semibold">Pausely</span>
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-400 to-purple-500" />
              </div>

              {/* App Content Preview */}
              <div className="p-8">
                <div className="mb-8">
                  <p className="text-white/50 text-base mb-2">Monthly Spending</p>
                  <p className="text-5xl font-bold mb-3">$247.00</p>
                  <div className="flex items-center gap-2 text-green-400 text-base">
                    <span>↓</span>
                    <span>$89 saved this month</span>
                  </div>
                </div>

                <div className="space-y-4">
                  {[
                    { name: 'Netflix', amount: '$15.99', change: '↓ 40%', color: 'text-red-400', bg: 'bg-red-500/10' },
                    { name: 'Spotify', amount: '$9.99', change: '↓ 20%', color: 'text-green-400', bg: 'bg-green-500/10' },
                    { name: 'Gym Membership', amount: '$49.99', change: 'Paused', color: 'text-orange-400', bg: 'bg-orange-500/10' },
                  ].map((sub, i) => (
                    <div key={i} className="flex items-center justify-between p-5 rounded-2xl bg-white/[0.03] hover:bg-white/[0.06] transition-colors">
                      <div className="flex items-center gap-4">
                        <div className={`w-12 h-12 rounded-xl ${sub.bg} flex items-center justify-center text-lg font-semibold`}>
                          {sub.name[0]}
                        </div>
                        <div>
                          <p className="font-semibold text-lg">{sub.name}</p>
                          <p className={`text-sm ${sub.color}`}>{sub.change}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="font-bold text-lg">{sub.amount}</p>
                        <p className="text-sm text-white/40">/month</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Floating Cards - Positioned for desktop */}
          <div className="absolute -left-16 top-1/4 glass rounded-2xl p-5 animate-float hidden xl:block max-w-[240px]">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-full bg-green-500/15 flex items-center justify-center text-2xl flex-shrink-0">
                💰
              </div>
              <div className="min-w-0">
                <p className="font-semibold text-base mb-0.5 truncate">Free Perk Found!</p>
                <p className="text-sm text-white/60 truncate">Chase → DashPass</p>
              </div>
            </div>
          </div>

          <div className="absolute -right-16 top-1/3 glass rounded-2xl p-5 animate-float hidden xl:block max-w-[240px]" style={{ animationDelay: '1.5s' }}>
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-full bg-blue-500/15 flex items-center justify-center text-2xl flex-shrink-0">
                ⏸️
              </div>
              <div className="min-w-0">
                <p className="font-semibold text-base mb-0.5 truncate">Subscription Paused</p>
                <p className="text-sm text-white/60 truncate">Netflix for 3 months</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
