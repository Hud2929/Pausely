import { useState, useEffect } from 'react'
import Navigation from './components/Navigation'
import Hero from './components/sections/Hero'
import AIFeatures from './components/sections/AIFeatures'
import Features from './components/sections/Features'
import HowItWorks from './components/sections/HowItWorks'
import Pricing from './components/sections/Pricing'
import CTA from './components/sections/CTA'
import Footer from './components/sections/Footer'
import Dashboard from './components/Dashboard'
import AuthPage from './components/AuthPage'
import { getCurrentUser, onAuthStateChange } from './lib/supabase'
import './styles/apple-design.css'

function App() {
  const [showDashboard, setShowDashboard] = useState(false)
  const [showAuth, setShowAuth] = useState(false)
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [loading, setLoading] = useState(true)

  // Check auth state on mount
  useEffect(() => {
    checkAuth()
    
    // Listen for auth state changes
    const { data: { subscription } } = onAuthStateChange((_event, session) => {
      setIsAuthenticated(!!session?.user)
      if (session?.user) {
        setShowDashboard(true)
        setShowAuth(false)
      }
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [])

  const checkAuth = async () => {
    try {
      const user = await getCurrentUser()
      setIsAuthenticated(!!user)
      if (user) {
        setShowDashboard(true)
      }
    } catch (error) {
      console.error('Auth check error:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleGetStarted = () => {
    if (isAuthenticated) {
      setShowDashboard(true)
    } else {
      setShowAuth(true)
    }
  }

  const handleAuthSuccess = () => {
    setIsAuthenticated(true)
    setShowDashboard(true)
    setShowAuth(false)
  }

  const handleBackToHome = () => {
    setShowDashboard(false)
    setShowAuth(false)
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-white/30 border-t-white rounded-full animate-spin" />
      </div>
    )
  }

  if (showAuth) {
    return <AuthPage onAuthSuccess={handleAuthSuccess} />
  }

  if (showDashboard) {
    return (
      <div className="relative">
        <button 
          onClick={handleBackToHome}
          className="fixed top-4 left-4 z-50 glass px-4 py-2 rounded-full flex items-center gap-2 text-sm"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
          </svg>
          Back to Home
        </button>
        <Dashboard />
      </div>
    )
  }

  return (
    <div className="bg-black min-h-screen relative overflow-hidden">
      <div className="animated-bg" />
      <div className="orb orb-1" />
      <div className="orb orb-2" />
      <div className="orb orb-3" />

      <Navigation 
        onGetStarted={handleGetStarted}
        isAuthenticated={isAuthenticated}
      />
      
      <main className="relative z-10">
        <Hero onGetStarted={handleGetStarted} />
        <AIFeatures />
        <Features />
        <HowItWorks />
        <Pricing onGetStarted={handleGetStarted} />
        <CTA onGetStarted={handleGetStarted} />
      </main>
      
      <Footer />
    </div>
  )
}

export default App
