import Foundation
import KeyboardPreferences
import Supabase

@MainActor
final class UserSession: ObservableObject {
    struct Profile: Equatable {
        let id: UUID
        let displayName: String
        let email: String
        let createdAt: Date
        let compositionDisplayMode: CompositionDisplayMode
    }

    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(Profile)
    }

    @Published private(set) var state: State

    init(initialState: State = .loading) {
        self.state = initialState
    }

    var profile: Profile? {
        if case let .signedIn(profile) = state { return profile }
        return nil
    }

    var displayName: String {
        profile?.displayName ?? ""
    }

    func bootstrap() async {
        do {
            let session = try await supabase.auth.session
            let profile = try await loadProfile(for: session.user)
            state = .signedIn(profile)
            try? await refreshUserDictionaryCache(for: profile.id)
        } catch {
            UserDictionaryStore.writeEntries([])
            state = .signedOut
        }

        Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .signedOut, .userDeleted:
                    UserDictionaryStore.writeEntries([])
                    self.state = .signedOut
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let user = session?.user,
                       let profile = try? await self.loadProfile(for: user) {
                        self.state = .signedIn(profile)
                        try? await self.refreshUserDictionaryCache(for: profile.id)
                    }
                default:
                    break
                }
            }
        }
    }

    func signUp(name: String, email: String, password: String) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(name)]
        )
        let profile = try await loadProfile(for: response.user, fallbackName: name)
        state = .signedIn(profile)
        try? await refreshUserDictionaryCache(for: profile.id)
    }

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        let profile = try await loadProfile(for: session.user)
        state = .signedIn(profile)
        try? await refreshUserDictionaryCache(for: profile.id)
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        UserDictionaryStore.writeEntries([])
        state = .signedOut
    }

    func refreshUserDictionaryCache() async throws {
        guard let profile else {
            UserDictionaryStore.writeEntries([])
            return
        }
        try await refreshUserDictionaryCache(for: profile.id)
    }

    func updateCompositionDisplayMode(_ mode: CompositionDisplayMode) async throws {
        guard let profile else { return }

        struct UpdateRow: Encodable {
            let composition_display_mode: String
        }

        try await supabase
            .from("profiles")
            .update(UpdateRow(composition_display_mode: mode.rawValue))
            .eq("id", value: profile.id)
            .execute()

        state = .signedIn(Profile(
            id: profile.id,
            displayName: profile.displayName,
            email: profile.email,
            createdAt: profile.createdAt,
            compositionDisplayMode: mode
        ))
    }

    private func loadProfile(for user: User, fallbackName: String? = nil) async throws -> Profile {
        struct Row: Decodable {
            let id: UUID
            let display_name: String
            let created_at: Date
            let composition_display_mode: String
        }

        // RLS restricts the row to the current user, so no explicit filter needed.
        let row: Row = try await supabase
            .from("profiles")
            .select("id, display_name, created_at, composition_display_mode")
            .single()
            .execute()
            .value

        let mode = CompositionDisplayMode(rawValue: row.composition_display_mode) ?? .balancedRaw
        KeyboardSettingsStore.writeCompositionDisplayMode(mode)

        return Profile(
            id: row.id,
            displayName: row.display_name.isEmpty ? (fallbackName ?? user.email ?? "") : row.display_name,
            email: user.email ?? "",
            createdAt: row.created_at,
            compositionDisplayMode: mode
        )
    }

    private func refreshUserDictionaryCache(for userId: UUID) async throws {
        let entries = try await UserDictionaryRemoteStore.fetchEntries(for: userId)
        UserDictionaryStore.writeEntries(entries)
    }

}
