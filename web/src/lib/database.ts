import { supabase } from '../lib/supabase'
import type { 
  Subscription, 
  UserProfile, 
  CancellationRequest, 
  AIInsight,
  SubscriptionCategory 
} from '../types/subscription'

// User Profile Functions
export async function getUserProfile(userId: string): Promise<UserProfile | null> {
  const { data, error } = await supabase
    .from('user_profiles')
    .select('*')
    .eq('user_id', userId)
    .single()
  
  if (error) {
    console.error('Error fetching user profile:', error)
    return null
  }
  return data
}

export async function updateUserProfile(
  userId: string, 
  updates: Partial<UserProfile>
): Promise<{ data: UserProfile | null; error: Error | null }> {
  const { data, error } = await supabase
    .from('user_profiles')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('user_id', userId)
    .select()
    .single()
  
  return { data, error: error as Error | null }
}

// Subscription Functions
export async function getUserSubscriptions(userId: string): Promise<Subscription[]> {
  const { data, error } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
  
  if (error) {
    console.error('Error fetching subscriptions:', error)
    return []
  }
  return data || []
}

export async function getActiveSubscriptions(userId: string): Promise<Subscription[]> {
  const { data, error } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', userId)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
  
  if (error) {
    console.error('Error fetching active subscriptions:', error)
    return []
  }
  return data || []
}

export async function addSubscription(
  subscription: Omit<Subscription, 'id' | 'created_at' | 'updated_at'>
): Promise<{ data: Subscription | null; error: Error | null }> {
  const { data, error } = await supabase
    .from('subscriptions')
    .insert(subscription)
    .select()
    .single()
  
  return { data, error: error as Error | null }
}

export async function updateSubscription(
  subscriptionId: string,
  updates: Partial<Subscription>
): Promise<{ data: Subscription | null; error: Error | null }> {
  const { data, error } = await supabase
    .from('subscriptions')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('id', subscriptionId)
    .select()
    .single()
  
  return { data, error: error as Error | null }
}

export async function deleteSubscription(
  subscriptionId: string
): Promise<{ error: Error | null }> {
  const { error } = await supabase
    .from('subscriptions')
    .delete()
    .eq('id', subscriptionId)
  
  return { error: error as Error | null }
}

export async function pauseSubscription(
  subscriptionId: string
): Promise<{ data: Subscription | null; error: Error | null }> {
  return updateSubscription(subscriptionId, { status: 'paused' })
}

export async function resumeSubscription(
  subscriptionId: string
): Promise<{ data: Subscription | null; error: Error | null }> {
  return updateSubscription(subscriptionId, { status: 'active' })
}

// Calculate monthly spending
export function calculateMonthlySpending(subscriptions: Subscription[]): number {
  return subscriptions
    .filter(sub => sub.status === 'active')
    .reduce((total, sub) => {
      let monthlyAmount = sub.amount
      if (sub.billing_cycle === 'yearly') {
        monthlyAmount = sub.amount / 12
      } else if (sub.billing_cycle === 'weekly') {
        monthlyAmount = sub.amount * 4.33 // Average weeks per month
      }
      return total + monthlyAmount
    }, 0)
}

// Calculate yearly spending
export function calculateYearlySpending(subscriptions: Subscription[]): number {
  return subscriptions
    .filter(sub => sub.status === 'active')
    .reduce((total, sub) => {
      let yearlyAmount = sub.amount
      if (sub.billing_cycle === 'monthly') {
        yearlyAmount = sub.amount * 12
      } else if (sub.billing_cycle === 'weekly') {
        yearlyAmount = sub.amount * 52
      }
      return total + yearlyAmount
    }, 0)
}

// Get subscriptions by category
export function getSubscriptionsByCategory(subscriptions: Subscription[]): Record<SubscriptionCategory, Subscription[]> {
  return subscriptions.reduce((acc, sub) => {
    if (!acc[sub.category]) {
      acc[sub.category] = []
    }
    acc[sub.category].push(sub)
    return acc
  }, {} as Record<SubscriptionCategory, Subscription[]>)
}

// Cancellation Request Functions
export async function createCancellationRequest(
  request: Omit<CancellationRequest, 'id' | 'created_at' | 'updated_at'>
): Promise<{ data: CancellationRequest | null; error: Error | null }> {
  const { data, error } = await supabase
    .from('cancellation_requests')
    .insert(request)
    .select()
    .single()
  
  return { data, error: error as Error | null }
}

export async function getUserCancellationRequests(userId: string): Promise<CancellationRequest[]> {
  const { data, error } = await supabase
    .from('cancellation_requests')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
  
  if (error) {
    console.error('Error fetching cancellation requests:', error)
    return []
  }
  return data || []
}

// AI Insights Functions
export async function getUserInsights(userId: string, limit = 10): Promise<AIInsight[]> {
  const { data, error } = await supabase
    .from('ai_insights')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit)
  
  if (error) {
    console.error('Error fetching insights:', error)
    return []
  }
  return data || []
}

export async function markInsightAsRead(insightId: string): Promise<{ error: Error | null }> {
  const { error } = await supabase
    .from('ai_insights')
    .update({ is_read: true })
    .eq('id', insightId)
  
  return { error: error as Error | null }
}

// Check if user can add more subscriptions (free plan limit)
export function canAddSubscription(profile: UserProfile | null, currentCount: number): boolean {
  if (!profile) return false
  if (profile.plan_type === 'pro') return true
  return currentCount < 2 // Free plan limit
}

// Subscription Limits
export const SUBSCRIPTION_LIMITS = {
  free: 2,
  pro: Infinity
}
