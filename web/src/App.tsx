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
import { useState } from 'react'

function App() {
  const [showDashboard, setShowDashboard] = useState(false)

  if (showDashboard) {
    return <Dashboard />
  }

  return (
    <div className="bg-black min-h-screen relative overflow-hidden">
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
        <CTA onGetStarted={() => setShowDashboard(true)} />
      </main>
      
      <Footer />
    </div>
  )
}

export default App
