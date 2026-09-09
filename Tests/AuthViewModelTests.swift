import CryptoKit
import Foundation
@testable import happyFamily
import Testing

@Suite("Auth login contract")
@MainActor
struct AuthViewModelTests {
    // Contract §2: password must be 12+ characters with lowercase, uppercase,
    // number, and symbol classes.
    @Test func passwordPolicyRequiresSymbolClass() {
        let model = AuthViewModel(authSession: nil)
        model.isSignUpMode = true

        model.password = "Abcdefgh1234"
        #expect(!model.isPasswordValid)
        #expect(model.passwordPrompt != nil)

        model.password = "Abcdefgh123!"
        #expect(model.isPasswordValid)
        #expect(model.passwordPrompt == nil)
    }

    @Test func signUpRejectsPasswordWithoutSymbolBeforeHittingBackend() async {
        let session = AuthSessionSpy()
        let model = AuthViewModel(authSession: session)
        model.email = "organizer@example.com"
        model.password = "Abcdefgh1234"
        model.isSignUpMode = true

        let authenticated = await model.submit()

        #expect(!authenticated)
        #expect(await !session.didSignUp)
    }

    @Test func appleSignInForwardsIdentityTokenAndRawNonce() async {
        let session = AuthSessionSpy()
        let model = AuthViewModel(authSession: session)
        let nonce = AppleSignInSupport.newNonce()

        let authenticated = await model.submitApple(idToken: "apple-id-token", nonce: nonce.raw)

        #expect(authenticated)
        let call = await session.appleCall
        #expect(call?.idToken == "apple-id-token")
        #expect(call?.nonce == nonce.raw)
    }

    @Test func appleSignInNoncePairsRawValueWithSha256Hash() {
        let nonce = AppleSignInSupport.newNonce()

        let digest = SHA256.hash(data: Data(nonce.raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        #expect(nonce.hashed == hex)
        #expect(AppleSignInSupport.newNonce().raw != nonce.raw)
    }

    @Test func appleSignInMapsInvalidCredentialsError() async {
        let session = AuthSessionSpy(
            appleError: NSError(
                domain: "GoTrue",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "invalid_credentials: Invalid login credentials"]
            )
        )
        let model = AuthViewModel(authSession: session)

        let authenticated = await model.submitApple(idToken: "apple-id-token", nonce: "nonce")

        #expect(!authenticated)
        #expect(model.errorMessage == "Email atau kata sandi salah.")
        #expect(model.isSubmitting == false)
    }
}

private struct AppleCall: Equatable, Sendable {
    let idToken: String
    let nonce: String
}

private actor AuthSessionSpy: AuthSession {
    let appleError: Error?
    private(set) var didSignUp = false
    private(set) var appleCall: AppleCall?

    init(appleError: Error? = nil) {
        self.appleError = appleError
    }

    func current() async throws -> AuthUserSession {
        Self.session
    }

    func signUp(email: String, password: String) async throws {
        didSignUp = true
    }

    func signIn(email: String, password: String) async throws -> AuthUserSession {
        Self.session
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUserSession {
        appleCall = AppleCall(idToken: idToken, nonce: nonce)
        if let appleError {
            throw appleError
        }
        return Self.session
    }

    func signOut() async throws {}

    private static let session = AuthUserSession(
        userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        accessToken: "access-token",
        expiresAt: Date(timeIntervalSince1970: 4_102_444_800)
    )
}
