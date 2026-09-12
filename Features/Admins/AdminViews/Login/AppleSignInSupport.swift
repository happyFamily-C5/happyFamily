import CryptoKit
import Foundation

/// Nonce shaping for Sign in with Apple backed by Supabase Auth.
///
/// Apple receives the SHA-256 hash of a fresh nonce in the authorization
/// request; the raw value travels to Supabase through
/// `AuthSession.signInWithApple` where it is verified against the identity
/// token. A fresh nonce per authorization request prevents replay of a
/// previous Apple response.
enum AppleSignInSupport {
    struct Nonce: Sendable, Equatable {
        /// Sent to Supabase together with the Apple identity token.
        let raw: String
        /// Sent to Apple in the authorization request.
        let hashed: String
    }

    static func newNonce() -> Nonce {
        let raw = randomNonceString()
        return Nonce(raw: raw, hashed: sha256Hex(raw))
    }

    private static let nonceCharacters = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
    )

    private static func randomNonceString(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes gagal: \(status)")

        var nonce = ""
        nonce.reserveCapacity(length)
        for byte in bytes {
            nonce.append(nonceCharacters[Int(byte) % nonceCharacters.count])
        }
        return nonce
    }

    private static func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
