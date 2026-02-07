export interface CancellationRequest {
  id: string
  user_id: string
  service_name: string
  status: 'drafting' | 'sent' | 'negotiating' | 'cancelled' | 'saved'
  messages: {
    id: string
    role: 'ai' | 'user' | 'company'
    content: string
    timestamp: string
    type?: 'email' | 'chat' | 'suggestion'
  }[]
  created_at: string
  updated_at: string
  total_saved?: number
}
