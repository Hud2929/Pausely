import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { PieChart, DollarSign, Gift, PauseCircle, ArrowRight } from 'lucide-react'

const slides = [
  {
    icon: PieChart,
    title: 'Track Your Subscriptions',
    description: 'Connect your bank accounts to automatically detect all your recurring charges in one place.',
    color: 'text-blue-600'
  },
  {
    icon: DollarSign,
    title: 'See True Value',
    description: 'See cost per hour instead of monthly fees. "Netflix - $8/hour" tells a different story than "$15.99/month".',
    color: 'text-green-600'
  },
  {
    icon: Gift,
    title: 'Unlock Free Perks',
    description: 'Discover $50-100/month in free alternatives you already have access to through credit cards, employer, and library.',
    color: 'text-purple-600'
  },
  {
    icon: PauseCircle,
    title: 'Pause, Don\'t Cancel',
    description: 'Many services let you pause instead of cancel. Less scary, keeps your data, reactivate instantly.',
    color: 'text-orange-600'
  }
]

export default function Onboarding() {
  const [currentSlide, setCurrentSlide] = useState(0)
  const [showAuth, setShowAuth] = useState(false)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [isSignUp, setIsSignUp] = useState(false)
  const [loading, setLoading] = useState(false)

  async function handleAuth(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)

    try {
      if (isSignUp) {
        const { error } = await supabase.auth.signUp({
          email,
          password,
        })
        if (error) throw error
        alert('Check your email for confirmation!')
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        })
        if (error) throw error
      }
    } catch (error: any) {
      alert(error.message)
    } finally {
      setLoading(false)
    }
  }

  if (showAuth) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4 bg-gray-50">
        <div className="bg-white rounded-2xl p-8 w-full max-w-sm shadow-lg">
          <h2 className="text-2xl font-bold mb-2 text-center">{isSignUp ? 'Create Account' : 'Welcome Back'}</h2>
          <p className="text-gray-500 text-center mb-6">
            {isSignUp ? 'Start saving on subscriptions' : 'Sign in to continue'}
          </p>

          <form onSubmit={handleAuth} className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-1">Email</label>
              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                className="w-full border border-gray-300 rounded-lg px-4 py-3"
                placeholder="you@example.com"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Password</label>
              <input
                type="password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                className="w-full border border-gray-300 rounded-lg px-4 py-3"
                placeholder="••••••••"
                required
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 text-white py-3 rounded-xl font-semibold disabled:opacity-50"
            >
              {loading ? 'Loading...' : isSignUp ? 'Create Account' : 'Sign In'}
            </button>
          </form>

          <p className="text-center mt-4 text-sm">
            {isSignUp ? 'Already have an account?' : "Don't have an account?"}{' '}
            <button
              onClick={() => setIsSignUp(!isSignUp)}
              className="text-blue-600 font-medium"
            >
              {isSignUp ? 'Sign In' : 'Create One'}
            </button>
          </p>

          <button
            onClick={() => setShowAuth(false)}
            className="w-full mt-4 text-gray-500 text-sm"
          >
            ← Back to onboarding
          </button>
        </div>
      </div>
    )
  }

  const slide = slides[currentSlide]
  const Icon = slide.icon

  return (
    <div className="min-h-screen flex flex-col bg-gray-50">
      <div className="flex-1 flex flex-col items-center justify-center p-6">
        <div className={`w-32 h-32 rounded-full flex items-center justify-center mb-8 bg-white shadow-sm`}>
          <Icon className={`w-16 h-16 ${slide.color}`} />
        </div>

        <h1 className="text-2xl font-bold mb-4 text-center">{slide.title}</h1>
        <p className="text-gray-500 text-center max-w-sm">{slide.description}</p>
      </div>

      <div className="p-6 pb-12">
        {/* Progress dots */}
        <div className="flex justify-center gap-2 mb-8">
          {slides.map((_, idx) => (
            <button
              key={idx}
              onClick={() => setCurrentSlide(idx)}
              className={`w-2 h-2 rounded-full transition-all ${
                idx === currentSlide ? 'w-6 bg-blue-600' : 'bg-gray-300'
              }`}
            />
          ))}
        </div>

        <div className="space-y-3">
          {currentSlide === slides.length - 1 ? (
            <button
              onClick={() => setShowAuth(true)}
              className="w-full bg-blue-600 text-white py-4 rounded-xl font-semibold flex items-center justify-center gap-2"
            >
              Get Started
              <ArrowRight className="w-5 h-5" />
            </button>
          ) : (
            <button
              onClick={() => setCurrentSlide(currentSlide + 1)}
              className="w-full bg-blue-600 text-white py-4 rounded-xl font-semibold"
            >
              Next
            </button>
          )}

          {currentSlide < slides.length - 1 && (
            <button
              onClick={() => setShowAuth(true)}
              className="w-full text-gray-500 py-3 font-medium"
            >
              Skip
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
