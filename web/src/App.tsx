import { useState, useEffect } from 'react'
import './index.css'
import Dashboard from './components/Dashboard'
import Subscriptions from './components/Subscriptions'
import Perks from './components/Perks'
import Profile from './components/Profile'
import Onboarding from './components/Onboarding'
import { supabase } from './lib/supabase'
import { LayoutDashboard, List, Gift, User } from 'lucide-react'

function App() {
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState('dashboard')

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })

    return () => subscription.unsubscribe()
  }, [])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  if (!session) {
    return <Onboarding />
  }

  const renderTab = () => {
    switch (activeTab) {
      case 'dashboard':
        return <Dashboard />
      case 'subscriptions':
        return <Subscriptions />
      case 'perks':
        return <Perks />
      case 'profile':
        return <Profile />
      default:
        return <Dashboard />
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <main className="pb-20">{renderTab()}</main>
      
      <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 px-4 py-2">
        <div className="flex justify-around items-center max-w-md mx-auto">
          <button
            onClick={() => setActiveTab('dashboard')}
            className={`flex flex-col items-center p-2 ${activeTab === 'dashboard' ? 'text-blue-600' : 'text-gray-500'}`}
          >
            <LayoutDashboard size={24} />
            <span className="text-xs mt-1">Dashboard</span>
          </button>
          <button
            onClick={() => setActiveTab('subscriptions')}
            className={`flex flex-col items-center p-2 ${activeTab === 'subscriptions' ? 'text-blue-600' : 'text-gray-500'}`}
          >
            <List size={24} />
            <span className="text-xs mt-1">Subscriptions</span>
          </button>
          <button
            onClick={() => setActiveTab('perks')}
            className={`flex flex-col items-center p-2 ${activeTab === 'perks' ? 'text-blue-600' : 'text-gray-500'}`}
          >
            <Gift size={24} />
            <span className="text-xs mt-1">Perks</span>
          </button>
          <button
            onClick={() => setActiveTab('profile')}
            className={`flex flex-col items-center p-2 ${activeTab === 'profile' ? 'text-blue-600' : 'text-gray-500'}`}
          >
            <User size={24} />
            <span className="text-xs mt-1">Profile</span>
          </button>
        </div>
      </nav>
    </div>
  )
}

export default App
