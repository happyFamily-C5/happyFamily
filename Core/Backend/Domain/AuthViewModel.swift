import Foundation
import Observation

/// Drives the login screen: email/password sign-in and first-time sign-up.
/// Sessions persist through the Supabase client's keychain storage, so this
/// view model only runs while the app has no usable session.
@MainActor
@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var isSignUpMode: Bool = false
    private(set) var isSubmitting: Bool = false
    var errorMessage: String?
    /// Optional success state shown without interrupting a usable session.
    var infoMessage: String?

    private let authSession: (any AuthSession)?

    init(authSession: (any AuthSession)?) {
        self.authSession = authSession
    }

    var isSubmitEnabled: Bool {
        !isSubmitting
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    var primaryButtonTitle: String {
        isSignUpMode ? "Daftar" : "Masuk"
    }

    var modeToggleText: String {
        isSignUpMode ? "Sudah punya akun? Masuk" : "Belum punya akun? Daftar"
    }

    var emailPrompt: String? {
        isEmailValid ? nil : "*Format email tidak valid"
    }

    var passwordPrompt: String? {
        guard isSignUpMode else { return nil }
        return isPasswordValid ? nil : "*Minimal 12 karakter, kombinasi huruf besar, kecil, angka, dan simbol"
    }

    var isEmailValid: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("@") && value.dropFirst(value.firstIndex(of: "@")?.utf16Offset(in: value) ?? 0).contains(".")
    }

    /// Contract §2: password must be 12+ characters with lowercase, uppercase,
    /// number, and symbol classes.
    var isPasswordValid: Bool {
        password.count >= 12
            && password.contains(where: \.isLowercase)
            && password.contains(where: \.isUppercase)
            && password.contains(where: \.isNumber)
            && password.contains(where: { !$0.isLetter && !$0.isNumber })
    }

    func submit() async -> Bool {
        guard let authSession else {
            errorMessage = "Konfigurasi backend belum lengkap."
            return false
        }
        guard isSubmitEnabled, isEmailValid else {
            errorMessage = "Periksa kembali email dan kata sandi."
            return false
        }
        if isSignUpMode, !isPasswordValid {
            errorMessage = "Periksa kembali email dan kata sandi."
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        infoMessage = nil
        do {
            if isSignUpMode {
                try await authSession.signUp(email: trimmedEmail, password: password)
                _ = try await authSession.current()
                infoMessage = "Akun berhasil dibuat."
                isSignUpMode = false
                return true
            }
            _ = try await authSession.signIn(email: trimmedEmail, password: password)
            errorMessage = nil
            return true
        } catch {
            errorMessage = Self.authErrorMessage(error)
            return false
        }
    }

    /// Sign in with Apple per contract §2: SIWA is active for Pengelola and
    /// signs in an existing user or provisions a new one server-side.
    /// `idToken` is the Apple identity token; `nonce` is the raw nonce whose
    /// SHA-256 hash was sent to Apple in the authorization request.
    func submitApple(idToken: String, nonce: String) async -> Bool {
        guard let authSession else {
            errorMessage = "Konfigurasi backend belum lengkap."
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        infoMessage = nil
        do {
            _ = try await authSession.signInWithApple(idToken: idToken, nonce: nonce)
            return true
        } catch {
            errorMessage = Self.authErrorMessage(error)
            return false
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func authErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        let lowered = message.lowercased()
        if lowered.contains("invalid_credentials") || lowered.contains("invalid login") {
            return "Email atau kata sandi salah."
        }
        if lowered.contains("already") && lowered.contains("registered") {
            return "Email sudah terdaftar. Silakan masuk."
        }
        if lowered.contains("email_not_confirmed") || lowered.contains("email not confirmed") {
            return "Konfirmasi email terlebih dahulu sebelum masuk."
        }
        if lowered.contains("weak_password") || lowered.contains("weak password") {
            return "Kata sandi minimal 12 karakter dengan huruf besar, kecil, angka, dan simbol."
        }
        if lowered.contains("rate limit") || lowered.contains("over_email_send_rate_limit") {
            return "Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi."
        }
        if lowered.contains("network") || lowered.contains("connect") {
            return "Koneksi ke server gagal. Periksa jaringan lalu coba lagi."
        }
        return message
    }
}
