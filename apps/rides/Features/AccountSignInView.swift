import SwiftUI

struct AccountSignInView: View {
    @EnvironmentObject private var store: RideStore
    @State private var creating = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var role = DemoRole.rider
    @State private var vehicle = ""
    @State private var plate = ""

    private var ready: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty &&
        (!creating || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 12 &&
        (role == .rider || (!vehicle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !plate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Rides").font(.system(size: 46, weight: .medium)).tracking(-2).padding(.top, 40)
                Image(systemName: "car.side.fill").font(.system(size: 54)).padding(.top, 24).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 10) {
                    Text(creating ? "Create your account" : "Let's get you moving").font(.system(size: 31, weight: .bold))
                    Text(creating ? "Your next ride starts here." : "Sign in to book a ride or get back on the road.").font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    if creating {
                        field("Full name") {
                            TextField("Full name", text: $name).textContentType(.name).accessibilityIdentifier("auth.name")
                        }
                    }
                    field("Email") {
                        TextField("Email address", text: $email).keyboardType(.emailAddress).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("auth.email")
                    }
                    field("Password") {
                        SecureField(creating ? "At least 12 characters" : "Password", text: $password).textContentType(creating ? .newPassword : .password).accessibilityIdentifier("auth.password")
                    }
                    if creating {
                        Picker("Account type", selection: $role) {
                            Text("Ride").tag(DemoRole.rider)
                            Text("Drive").tag(DemoRole.driver)
                        }.pickerStyle(.segmented).accessibilityIdentifier("auth.role")
                        if role == .driver {
                            field("Vehicle") {
                                TextField("Make, model and color", text: $vehicle).accessibilityIdentifier("auth.vehicle")
                            }
                            field("License plate") {
                                TextField("License plate", text: $plate).textInputAutocapitalization(.characters).autocorrectionDisabled().accessibilityIdentifier("auth.plate")
                            }
                        }
                    }
                }
                if let error = store.errorMessage {
                    Text(error).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("auth.error")
                }
                RidePrimaryButton(title: creating ? "Create account" : "Sign in", busy: store.busy, disabled: !ready) {
                    Task {
                        let registration = creating ? RideRegistration(name: name, email: email, password: password, role: role, vehicle: role == .driver ? vehicle : nil, plate: role == .driver ? plate : nil) : nil
                        if await store.signIn(email: email, password: password, registration: registration) { password = "" }
                    }
                }.accessibilityIdentifier("auth.submit")
                Button(creating ? "Already have an account? Sign in" : "New here? Create an account") {
                    creating.toggle()
                    password = ""
                    store.errorMessage = nil
                }.font(.subheadline.weight(.semibold)).foregroundStyle(.black).frame(maxWidth: .infinity).disabled(store.busy).accessibilityIdentifier("auth.switchMode")
                if creating {
                    Text("Email recovery and driver verification are currently unavailable.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 24).padding(.bottom, 30).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }.background(.white).scrollDismissesKeyboard(.interactively)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold))
            content().font(.body).padding(16).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
