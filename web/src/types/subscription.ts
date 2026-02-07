export interface UserProfile {
  id: string
  user_id: string
  email: string | null
  full_name: string | null
  currency_preference: string
  total_saved: number
  subscription_count: number
  plan_type: 'free' | 'pro'
  lemonsqueezy_customer_id: string | null
  lemonsqueezy_subscription_id: string | null
  created_at: string
  updated_at: string
}

export interface Subscription {
  id: string
  user_id: string
  name: string
  amount: number
  category: SubscriptionCategory
  status: 'active' | 'paused' | 'cancelled'
  renewal_date: string | null
  billing_cycle: 'monthly' | 'yearly' | 'weekly'
  website_url: string | null
  description: string | null
  logo_url: string | null
  created_at: string
  updated_at: string
}

export type SubscriptionCategory = 
  | 'streaming'
  | 'music'
  | 'gaming'
  | 'fitness'
  | 'software'
  | 'news'
  | 'food'
  | 'shopping'
  | 'other'

export interface CancellationRequest {
  id: string
  user_id: string
  subscription_id: string | null
  service_name: string
  status: 'drafting' | 'sent' | 'negotiating' | 'cancelled' | 'saved'
  email_content: string | null
  company_response: string | null
  final_status: string | null
  created_at: string
  updated_at: string
}

export interface AIInsight {
  id: string
  user_id: string
  type: 'savings' | 'perk' | 'reminder' | 'tip' | 'cancellation'
  title: string
  description: string
  amount: number | null
  is_read: boolean
  action_taken: boolean
  created_at: string
}

export interface PauseHistory {
  id: string
  user_id: string
  subscription_id: string
  paused_at: string
  resumed_at: string | null
  amount_saved: number
}

export const SUBSCRIPTION_CATEGORIES: { value: SubscriptionCategory; label: string; icon: string }[] = [
  { value: 'streaming', label: 'Streaming', icon: '🎬' },
  { value: 'music', label: 'Music', icon: '🎵' },
  { value: 'gaming', label: 'Gaming', icon: '🎮' },
  { value: 'fitness', label: 'Fitness', icon: '💪' },
  { value: 'software', label: 'Software', icon: '💻' },
  { value: 'news', label: 'News', icon: '📰' },
  { value: 'food', label: 'Food & Delivery', icon: '🍔' },
  { value: 'shopping', label: 'Shopping', icon: '🛍️' },
  { value: 'other', label: 'Other', icon: '📦' }
]

export const POPULAR_SERVICES = [
  'Netflix',
  'Spotify',
  'Adobe Creative Cloud',
  'Disney+',
  'Hulu',
  'Amazon Prime',
  'Xbox Game Pass',
  'PlayStation Plus',
  'Apple Music',
  'YouTube Premium',
  'DoorDash DashPass',
  'Uber One',
  'Peloton',
  'Gym Membership',
  'New York Times',
  'Medium',
  'LinkedIn Premium',
  'Notion',
  'Figma',
  'GitHub Pro',
  'ChatGPT Plus',
  'Midjourney',
  'Duolingo Plus',
  'Calm',
  'Headspace'
]
