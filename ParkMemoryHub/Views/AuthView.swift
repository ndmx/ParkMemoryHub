import SwiftUI

struct AuthView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var familyCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App Logo/Title
                    VStack(spacing: 20) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .scaleEffect(isSignUp ? 1.1 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isSignUp)
                        
                        Text("ParkMemory Hub")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Share memories with your family")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        if isSignUp {
                            TextField("Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        }
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if isSignUp {
                            TextField("Family Code", text: $familyCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        }
                        
                        // Action Button
                        Button(action: handleAuth) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading || !isValidInput)
                        
                        // Toggle Button
                        Button(action: { 
                            withAnimation(.spring()) {
                                isSignUp.toggle()
                                errorMessage = ""
                            }
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .foregroundColor(.white)
                                .underline()
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isValidInput: Bool {
        let emailValid = isValidEmail(email)
        let passwordValid = password.count >= 6
        
        if isSignUp {
            return emailValid && passwordValid && !username.isEmpty && !familyCode.isEmpty
        } else {
            return emailValid && passwordValid
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func handleAuth() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                if isSignUp {
                    _ = try await firebaseService.signUp(
                        email: email,
                        password: password,
                        username: username,
                        familyCode: familyCode
                    )
                } else {
                    _ = try await firebaseService.signIn(email: email, password: password)
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showAlert = true
                }
            }
            
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
}
