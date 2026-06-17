import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

// MARK: - AuthUser

struct AuthUser {
    let uid:         String
    let displayName: String
    let email:       String
    let photoURL:    URL?
    let isAnonymous: Bool

    init(from user: FirebaseAuth.User) {
        self.uid         = user.uid
        self.displayName = user.displayName ?? (user.isAnonymous ? "Guest" : "Student")
        self.email       = user.email       ?? ""
        self.photoURL    = user.photoURL
        self.isAnonymous = user.isAnonymous
    }
}

// MARK: - FirebaseAuthService

/// Singleton that manages all Firebase Auth methods:
///   • Google Sign-In
///   • Email + Password (login & create account)
///   • Phone number OTP
///
/// IMPORTANT: Call `startListening()` after `FirebaseApp.configure()` in AppDelegate.
@MainActor
final class FirebaseAuthService: ObservableObject {

    static let shared = FirebaseAuthService()

    @Published var currentUser:  AuthUser? = nil
    @Published var isLoading:    Bool      = false
    @Published var errorMessage: String?   = nil

    /// Stored during phone-auth step 1; consumed in step 2 (OTP verify)
    private(set) var phoneVerificationID: String? = nil

    private var stateHandle: AuthStateDidChangeListenerHandle?

    // init() must NOT touch Firebase — called before FirebaseApp.configure()
    private init() {}

    deinit {
        if let h = stateHandle { Auth.auth().removeStateDidChangeListener(h) }
    }

    // MARK: - Lifecycle

    /// Register the Firebase auth-state listener.
    /// Must be called AFTER FirebaseApp.configure().
    func startListening() {
        guard stateHandle == nil else { return }
        stateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user.map { AuthUser(from: $0) }
            }
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase not configured."
            return
        }
        isLoading = true; errorMessage = nil

        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Cannot find root view controller."
            isLoading = false; return
        }

        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result   = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let id = result.user.idToken?.tokenString else { throw AuthError.missingToken }
            let cred     = GoogleAuthProvider.credential(withIDToken: id,
                                                         accessToken: result.user.accessToken.tokenString)
            let auth     = try await Auth.auth().signIn(with: cred)
            currentUser  = AuthUser(from: auth.user)
        } catch GIDSignInError.canceled {
            // user dismissed
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Email + Password

    func signInWithEmail(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        do {
            let result  = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser = AuthUser(from: result.user)
        } catch {
            errorMessage = friendlyFirebaseError(error)
        }
        isLoading = false
    }

    func createAccount(name: String, email: String, password: String) async {
        isLoading = true; errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // Set display name
            let req    = result.user.createProfileChangeRequest()
            req.displayName = name
            try await req.commitChanges()
            currentUser = AuthUser(from: Auth.auth().currentUser ?? result.user)
        } catch {
            errorMessage = friendlyFirebaseError(error)
        }
        isLoading = false
    }

    func resetPassword(email: String) async {
        isLoading = true; errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = friendlyFirebaseError(error)
        }
        isLoading = false
    }

    // MARK: - Phone OTP

    /// Step 1 — Send OTP. Returns true on success.
    /// phoneNumber must include country code, e.g. "+628123456789"
    func sendPhoneOTP(phoneNumber: String) async -> Bool {
        isLoading = true; errorMessage = nil
        do {
            let verificationID = try await PhoneAuthProvider.provider()
                .verifyPhoneNumber(phoneNumber, uiDelegate: nil)
            self.phoneVerificationID = verificationID
            isLoading = false
            return true
        } catch {
            errorMessage = friendlyFirebaseError(error)
            isLoading = false
            return false
        }
    }

    /// Step 2 — Verify OTP code entered by user.
    func verifyPhoneOTP(code: String) async {
        guard let verificationID = phoneVerificationID else {
            errorMessage = "Verification session expired. Please resend OTP."
            return
        }
        isLoading = true; errorMessage = nil
        do {
            let cred    = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: code
            )
            let result  = try await Auth.auth().signIn(with: cred)
            currentUser = AuthUser(from: result.user)
        } catch {
            errorMessage = friendlyFirebaseError(error)
        }
        isLoading = false
    }

    // MARK: - Anonymous Sign-In

    /// Create a temporary anonymous account — user can upgrade later by linking a provider.
    func signInAnonymously() async {
        isLoading = true; errorMessage = nil
        do {
            let result  = try await Auth.auth().signInAnonymously()
            currentUser = AuthUser(from: result.user)
        } catch {
            errorMessage = friendlyFirebaseError(error)
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser          = nil
            phoneVerificationID  = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    var isSignedIn: Bool { currentUser != nil }

    private func friendlyFirebaseError(_ error: Error) -> String {
        let nsError   = error as NSError
        let errorCode = AuthErrorCode.Code(rawValue: nsError.code)
        switch errorCode {
        case .emailAlreadyInUse:        return "That email is already registered. Try logging in."
        case .wrongPassword:            return "Incorrect password. Please try again."
        case .invalidEmail:             return "Please enter a valid email address."
        case .weakPassword:             return "Password must be at least 6 characters."
        case .userNotFound:             return "No account found with that email."
        case .tooManyRequests:          return "Too many attempts. Please try again later."
        case .networkError:             return "No internet connection. Check your network."
        case .invalidVerificationCode:  return "Invalid OTP code. Please check and try again."
        case .sessionExpired:           return "OTP expired. Please resend the code."
        default:                        return error.localizedDescription
        }
    }
}

// MARK: - AuthError

private enum AuthError: LocalizedError {
    case missingToken
    var errorDescription: String? { "Google sign-in token was missing." }
}
