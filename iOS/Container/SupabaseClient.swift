import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://wsttwofhxbcgfpwvxazj.supabase.co")!
    static let publishableKey = "sb_publishable_-e1Ql6JWvgysYmfbrL0Www_bO5TDjl6"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.publishableKey
)
