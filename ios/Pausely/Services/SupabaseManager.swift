import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // Replace with your Supabase URL and anon key
        let supabaseURL = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
        let supabaseKey = "YOUR_ANON_KEY"
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
}
