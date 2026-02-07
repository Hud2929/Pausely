import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { Eye, EyeOff, ArrowRight, Loader2, CheckCircle2 } from 'lucide-react'

interface AuthPageProps {
  onAuthSuccess: () => void
}

export default function AuthPage({ onAuthSuccess }: AuthPageProps) {
  const [isLogin, setIsLogin] = useState(true)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    setSuccess('')

    try {
      if (isLogin) {
        const { data, error } = await supabase.auth.signInWithPassword({
          email,
          password
        })
        if (error) {
          if (error.message.includes('Invalid login')) {
            setError('Invalid email or password. Please try again.')
          } else {
            setError(error.message)
          }
          setLoading(false)
          return
        }
        if (data.user) {
          onAuthSuccess()
        }
      } else {
        // Sign up without email confirmation
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              email_confirm: true
            }
          }
        })
        
        if (error) {
          if (error.message.includes('rate limit')) {
            setError('Too many attempts. Please wait a minute and try again.')
          } else if (error.message.includes('already registered')) {
            setError('This email is already registered. Please sign in instead.')
          } else {
            setError(error.message)
          }
          setLoading(false)
          return
        }
        
        if (data.user) {
          setSuccess('Account created! Signing you in...')
          // Auto sign in after signup
          setTimeout(async () => {
            const { error: signInError } = await supabase.auth.signInWithPassword({
              email,
              password
            })
            if (!signInError) {
              onAuthSuccess()
            }
          }, 1500)
        }
      }
    } catch (err: any) {
      setError('Something went wrong. Please try again.')
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-black flex items-center justify-center p-4 relative overflow-hidden">
      <div className="animated-bg absolute inset-0" />
      <div className="orb orb-1 absolute" />
      <div className="orb orb-2 absolute" />

      <div className="relative z-10 w-full max-w-md">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold mb-2">Pausely</h1>
          <p className="text-white/50">{isLogin ? 'Welcome back' : 'Create your account'}</p>
        </div>

        <form onSubmit={handleSubmit} className="glass rounded-3xl p-8">
          {error && (
            <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              {error}
            </div>
          )}

          {success && (
            <div className="mb-6 p-4 rounded-xl bg-green-500/10 border border-green-500/20 text-green-400 text-sm flex items-center gap-2">
              <CheckCircle2 className="w-5 h-5" />
              {success}
            </div>
          )}

          <div className="space-y-6">
            <div>
              <label className="block text-sm font-medium text-white/70 mb-2">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                className="input"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-white/70 mb-2">Password</label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Min 6 characters"
                  className="input pr-12"
                  required
                  minLength={6}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-white/40 hover:text-white/70"
                >
                  {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full btn-primary mt-8 flex items-center justify-center gap-2"
          >
            {loading ? (
              <Loader2 className="w-5 h-5 animate-spin" />
            ) : (
              <>
                {isLogin ? 'Sign In' : 'Create Account'}
                <ArrowRight className="w-5 h-5" />
              </>
            )}
          </button>

          <div className="mt-6 text-center">
            <button
              type="button"
              onClick={() => {
                setIsLogin(!isLogin)
                setError('')
                setSuccess('')
              }}
              className="text-sm text-white/50 hover:text-white transition-colors"
            >
              {isLogin ? "Don't have an account? Sign up" : 'Already have an account? Sign in'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
