import Navigation from './components/Navigation'
import Hero from './components/sections/Hero'
import AIFeatures from './components/sections/AIFeatures'
import Features from './components/sections/Features'
import HowItWorks from './components/sections/HowItWorks'
import Pricing from './components/sections/Pricing'
import CTA from './components/sections/CTA'
import Footer from './components/sections/Footer'
import Dashboard from './components/Dashboard'
import './styles/apple-design.css'
import { useEffect, useState } from 'react'
import { supabase } from './lib/supabase'

function App() {
  const [session, setSession] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })

    // Listen for auth changes (magic link, etc)
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      console.log('Auth state changed:', _event, session)
      setSession(session)
      setLoading(false)
    })

    return () => subscription.unsubscribe()
  }, [])

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-white/20 border-t-white rounded-full animate-spin" />
      </div>
    )
  }

  if (session) {
    return <Dashboard />
  }

  return (
    <div className="bg-black min-h-screen relative overflow-hidden">
      {/* Animated Background */}
      <div className="animated-bg" />
      <div className="orb orb-1" />
      <div className="orb orb-2" />
      <div className="orb orb-3" />

      <Navigation />
      
      <main className="relative z-10">
        <Hero />
        <AIFeatures />
        <Features />
        <HowItWorks />
        <Pricing />
        <CTA />
      </main>
      
      <Footer />
    </div>
  )
}

export default App
