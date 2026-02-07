import { useState } from 'react'
import { ArrowRight } from 'lucide-react'
import { supabase } from '../../lib/supabase'

export default function CTA() {
  const [email, setEmail] = useState('')
  const [isSuccess, setIsSuccess] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    await supabase.auth.signInWithOtp({ email })
    setIsSuccess(true)
  }

  return (
    <section id="cta" className="section bg-[#050505]">
      <div className="container max-w-2xl text-center">
        <h2 className="headline-medium mb-6">
          Start saving today.
        </h2>

        <p className="body-large mb-12">
          Join 10,000+ users. 14-day free trial.
        </p>

        {!isSuccess ? (
          <form onSubmit={handleSubmit} className="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
          >
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Enter your email"
              className="input flex-1"
              required
            />
            <button type="submit" className="btn-primary whitespace-nowrap">
              Get Started
              <ArrowRight className="w-5 h-5 ml-2" />
            </button>
          </form>
        ) : (
          <div className="p-6 rounded-2xl bg-green-500/10 border border-green-500/20">
            <p className="text-green-400">Check your email for the magic link.</p>
          </div>
        )}
      </div>
    </section>
  )
}
