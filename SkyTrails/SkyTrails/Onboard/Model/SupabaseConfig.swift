import Foundation

struct SupabaseConfig {
    let projectURL: URL
    let anonKey: String

    static func load() throws -> SupabaseConfig {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !anonKey.isEmpty,
            !urlString.contains("YOUR_PROJECT_REF"),
            !anonKey.contains("YOUR_SUPABASE_ANON_KEY")
        else {
            throw SupabaseAuthError.notConfigured
        }

        return SupabaseConfig(projectURL: url, anonKey: anonKey)
    }
}

