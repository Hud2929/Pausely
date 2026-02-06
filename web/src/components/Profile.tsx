import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { User, Bell, Link, Clock, LogOut } from 'lucide-react'

export default function Profile() {
  const [loading, setLoading] = useState(false)

  async function handleSignOut() {
    setLoading(true)
    await supabase.auth.signOut()
    setLoading(false)
  }

  return (
    <div className="max-w-md mx-auto px-4 py-6">
      <h1 className="text-2xl font-bold mb-6">Profile</h1>

      {/* User Card */}
      <div className="bg-white rounded-2xl p-6 shadow-sm mb-6">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-blue-600 rounded-full flex items-center justify-center">
            <User className="w-8 h-8 text-white" />
          </div>
          <div>
            <p className="font-bold text-lg">Hudson</p>
            <p className="text-sm text-gray-500">hudson@pausely.pro</p>
            <span className="inline-block mt-1 px-3 py-1 bg-blue-100 text-blue-700 text-xs rounded-full">
              Free Plan
            </span>
          </div>
        </div>
      </div>

      {/* Settings */}
      <div className="bg-white rounded-2xl shadow-sm mb-6">
        <div className="p-4 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Bell className="w-5 h-5 text-gray-400" />
            <span>Notifications</span>
          </div>
          <span className="text-gray-400">></span>
        </div>
        
        <div className="p-4 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link className="w-5 h-5 text-gray-400" />
            <span>Connected Banks</span>
          </div>
          <span className="text-gray-400">></span>
        </div>
        
        <div className="p-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Clock className="w-5 h-5 text-gray-400" />
            <span>Screen Time</span>
          </div>
          <span className="text-gray-400">></span>
        </div>
      </div>

      {/* Sign Out */}
      <button
        onClick={handleSignOut}
        disabled={loading}
        className="w-full bg-white text-red-600 py-4 rounded-2xl font-semibold shadow-sm flex items-center justify-center gap-2"
      >
        <LogOut className="w-5 h-5" />
        {loading ? 'Signing out...' : 'Sign Out'}
      </button>
    </div>
  )
}
