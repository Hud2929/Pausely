import { useState } from 'react'
import { ArrowRight, Check, Sparkles } from 'lucide-react'
import { supabase } from '../../lib/supabase'

export default function CTA() {
  const [email, setEmail] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    setError('')

    try {
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`
        }
      })

      if (error) throw error

      setIsSuccess(true)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <section id="cta" className="relative section overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-b from-black via-[#0a0a0a] to-black" />
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-gradient-to-r from-blue-500/20 via-purple-500/20 to-pink-500/20 rounded-full blur-3xl opacity-50" />
      </div>

      <div className="container relative z-10">
        <div className="max-w-3xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 mb-8">
            <Sparkles className="w-4 h-4 text-yellow-400" />
            <span className="text-sm text-white/80">Start your free 14-day trial today</span>
          </div>

          {/* Headline */}
          <h2 className="headline-large mb-6">
            Ready to start{' '}
            <span className="gradient-text">saving?</span>
          </h2>

          <p className="body-large mb-10 max-w-xl mx-auto">
            Join 10,000+ users who have saved over $2.4 million on subscriptions. 
            No credit card required.
          </p>

          {!isSuccess ? (
            <form onSubmit={handleSubmit} className="max-w-md mx-auto">
              <div className="flex flex-col sm:flex-row gap-3">
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="Enter your email"
                  className="input flex-1"
                  required
                />
                <button
                  type="submit"
                  disabled={isLoading}
                  className="btn-primary whitespace-nowrap"
                >
                  {isLoading ? (
                    'Sending...'
                  ) : (
                    <>
                      Get Started
                      <ArrowRight className="w-5 h-5 ml-2" />
                    </>
                  )}
                </button>
              </div>

              {error && (
                <p className="text-red-400 text-sm mt-3">{error}</p>
              )}

              <p className="text-white/40 text-xs mt-4">
                By signing up, you agree to our Terms of Service and Privacy Policy.
              </p>
            </form>
          ) : (
            <div className="max-w-md mx-auto p-6 rounded-2xl bg-green-500/10 border border-green-500/20">
              <div className="flex items-center justify-center gap-2 mb-4">
                <div className="w-12 h-12 rounded-full bg-green-500/20 flex items-center justify-center">
                  <Check className="w-6 h-6 text-green-400" />
                </div>
              </div>
              <h3 className="text-xl font-semibold mb-2">Check your email!</h3>
              <p className="text-white/60">
                We've sent a magic link to {email}. Click it to sign in and start saving.
              </p>
            </div>
          )}

          {/* Trust Indicators */}
          <div className="mt-12 flex flex-wrap items-center justify-center gap-8 text-white/40">
            <div className="flex items-center gap-2">
              <Check className="w-4 h-4 text-green-400" />
              <span className="text-sm">14-day free trial</span>
            </div>
            <div className="flex items-center gap-2">
              <Check className="w-4 h-4 text-green-400" />
              <span className="text-sm">No credit card</span>
            </div>
            <div className="flex items-center gap-2">
              <Check className="w-4 h-4 text-green-400" />
              <span className="text-sm">Cancel anytime</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
