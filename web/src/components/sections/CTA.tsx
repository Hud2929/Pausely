import { useState } from 'react'
import { ArrowRight, CheckCircle2 } from 'lucide-react'
import { supabase } from '../../lib/supabase'

export default function CTA() {
  const [email, setEmail] = useState('')
  const [isSuccess, setIsSuccess] = useState(false)
  const [isLoading, setIsLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    await supabase.auth.signInWithOtp({ 
      email,
      options: {
        emailRedirectTo: 'https://pausely.pro/dashboard'
      }
    })
    setIsLoading(false)
    setIsSuccess(true)
  }

  return (
    <section id="cta" className="section">
      <div className="container max-w-2xl text-center">
        <p className="caption mb-6">Get Started</p>
        
        <h2 className="headline-medium mb-8">
          Start saving today.
        </h2>

        <p className="body-large mb-16">
          Join thousands of users. 14-day free trial, no credit card required.
        </p>

        {!isSuccess ? (
          <form onSubmit={handleSubmit} className="max-w-md mx-auto"
          >
            <div className="flex flex-col sm:flex-row gap-4">
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
                className="btn-primary whitespace-nowrap"
                disabled={isLoading}
              >
                {isLoading ? (
                  <span className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : (
                  <>
                    Get Started
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </>
                )}
              </button>
            </div>
            
            <p className="mt-6 text-sm text-white/30">
              Free forever plan available
            </p>
          </form>
        ) : (
          <div className="flex items-center justify-center gap-3 p-8 rounded-3xl glass max-w-md mx-auto">
            <CheckCircle2 className="w-8 h-8 text-green-400" />
            <div className="text-left">
              <p className="text-white font-medium">Check your email</p>
              <p className="text-white/50 text-sm">We've sent you a magic link</p>
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
