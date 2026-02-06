import { CreditCard, Building2, BookOpen, Shield, Users, Gift } from 'lucide-react'

const perkSources = [
  {
    icon: CreditCard,
    title: 'Credit Cards',
    subtitle: 'Chase, Amex, Citi perks',
    examples: ['DashPass', 'Uber credits', 'Lounge access']
  },
  {
    icon: Building2,
    title: 'Employer Benefits',
    subtitle: 'Wellness, learning stipends',
    examples: ['Calm Premium', 'Headspace', 'Coursera']
  },
  {
    icon: BookOpen,
    title: 'Library',
    subtitle: 'Free streaming, audiobooks',
    examples: ['Kanopy', 'Libby', 'Hoopla']
  },
  {
    icon: Shield,
    title: 'Insurance',
    subtitle: 'Health, auto perks',
    examples: ['Gym discounts', 'Apple Watch program']
  },
  {
    icon: Users,
    title: 'Memberships',
    subtitle: 'Costco, AAA, alumni',
    examples: ['Travel discounts', 'Insurance savings']
  }
]

export default function Perks() {
  return (
    <div className="max-w-md mx-auto px-4 py-6">
      <div className="text-center mb-8">
        <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <Gift className="w-10 h-10 text-green-600" />
        </div>
        <h1 className="text-2xl font-bold mb-2">Free Perks</h1>
        <p className="text-gray-500">
          Discover free subscriptions you already have access to
        </p>
      </div>

      <div className="bg-blue-50 rounded-xl p-4 mb-6 border border-blue-200">
        <p className="text-sm text-blue-800">
          <strong>Did you know?</strong> The average user discovers $50-100/month in free alternatives they didn't know about!
        </p>
      </div>

      <div className="space-y-3">
        {perkSources.map((source, idx) => (
          <div key={idx} className="bg-white rounded-xl p-4 shadow-sm">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-blue-50 rounded-xl flex items-center justify-center">
                <source.icon className="w-6 h-6 text-blue-600" />
              </div>
              
              <div className="flex-1">
                <p className="font-semibold">{source.title}</p>
                <p className="text-sm text-gray-500">{source.subtitle}</p>
                <p className="text-xs text-gray-400 mt-1">
                  {source.examples.join(' • ')}
                </p>
              </div>
            </div>
          </div>
        ))}
      </div>

      <button className="w-full mt-6 bg-blue-600 text-white py-4 rounded-xl font-semibold">
        Connect Accounts to Find Perks
      </button>
    </div>
  )
}
