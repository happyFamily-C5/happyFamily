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
    /// Shown after a successful sign-up that awaits e-mail confirmation.
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
        return isPasswordValid ? nil : "*Minimal 12 karakter, kombinasi huruf besar, kecil, dan angka"
    }

    var isEmailValid: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("@") && value.dropFirst(value.firstIndex(of: "@")?.utf16Offset(in: value) ?? 0).contains(".")
    }

    var isPasswordValid: Bool {
        password.count >= 12
            && password.contains(where: \.isLowercase)
            && password.contains(where: \.isUppercase)
            && password.contains(where: \.isNumber)
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
        if isSignUpMode && !isPasswordValid {
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
                // Hosted projects require e-mail confirmation before the
                // session becomes usable; surface that instead of entering.
                infoMessage = "Akun berhasil dibuat. Buka tautan konfirmasi di emailmu, lalu masuk."
                isSignUpMode = false
                return false
            }
            _ = try await authSession.signIn(email: trimmedEmail, password: password)
            errorMessage = nil
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
        if lowered.contains("rate limit") || lowered.contains("over_email_send_rate_limit") {
            return "Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi."
        }
        if lowered.contains("network") || lowered.contains("connect") {
            if isLocalBackend {
                return "Backend lokal (127.0.0.1) tidak dapat dijangkau dari perangkat fisik. Jalankan scheme \"happyFamily Staging\" untuk uji di iPhone."
            }
            return "Koneksi ke server gagal. Periksa jaringan lalu coba lagi."
        }
        return message
    }

    private static var isLocalBackend: Bool {
        (try? BackendEnvironment.load())?.deployment == .local
    }
}
