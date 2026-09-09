import Foundation
import Supabase

actor SupabaseAuthSession: AuthSession {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func current() async throws -> AuthUserSession {
        let session = try await client.auth.session
        return Self.map(session)
    }

    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> AuthUserSession {
        let session = try await client.auth.signIn(email: email, password: password)
        return Self.map(session)
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUserSession {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        return Self.map(session)
    }

    func signOut() async throws {
        try await client.auth.signOut(scope: .global)
    }

    private static func map(_ session: Session) -> AuthUserSession {
        AuthUserSession(
            userId: session.user.id,
            accessToken: session.accessToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }
}
