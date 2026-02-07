import Navigation from './components/Navigation'
import Hero from './components/sections/Hero'
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

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })

    return () => subscription.unsubscribe()
  }, [])

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
