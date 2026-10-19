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
    @State private var showPassword = false
    @State private var submitted = false
    @State private var touched: Set<RideAccountField> = []
    @FocusState private var focusedField: RideAccountField?

    private var errors: [RideAccountField: String] {
        RideAccountValidation.errors(name: name, email: email, password: password, creating: creating, role: role, vehicle: vehicle, plate: plate)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("Rides").font(.system(size: 28, weight: .bold)).tracking(-1).padding(.top, 16)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(creating ? "Create your account" : "Welcome back")
                                .font(.system(size: 32, weight: .bold)).tracking(-0.8)
                                .accessibilityAddTraits(.isHeader)
                            Text(creating ? "A few details, then you're ready to go." : "Sign in to ride or get back on the road.")
                                .font(.system(size: 16)).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 20) {
                            if creating {
                                field("Full name", id: .name) {
                                    TextField("Your full name", text: $name)
                                        .textContentType(.name).textInputAutocapitalization(.words)
                                        .focused($focusedField, equals: .name).submitLabel(.next)
                                        .onSubmit { focusedField = .email }
                                        .accessibilityIdentifier("auth.name")
                                }
                            }
                            field("Email address", id: .email) {
                                TextField("name@example.com", text: $email)
                                    .keyboardType(.emailAddress).textContentType(creating ? .emailAddress : .username)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .focused($focusedField, equals: .email).submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                                    .accessibilityIdentifier("auth.email")
                            }
                            field("Password", id: .password) {
                                HStack(spacing: 12) {
                                    RidePasswordField(text: $password, focused: Binding(get: { focusedField == .password }, set: { value in
                                        if value { focusedField = .password }
                                        else if focusedField == .password { focusedField = nil }
                                    }), secure: !showPassword, creating: creating, returnKey: creating && role == .driver ? .next : .go) {
                                        if creating && role == .driver { focusedField = .vehicle }
                                        else { submit() }
                                    }.frame(height: 32)
                                    .accessibilityIdentifier("auth.password")
                                    Button {
                                        showPassword.toggle()
                                        focusedField = .password
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .font(.system(size: 18)).foregroundStyle(.secondary)
                                            .frame(width: 32, height: 32).contentShape(Rectangle())
                                    }
                                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                                    .accessibilityIdentifier("auth.togglePassword")
                                }
                            }
                            if creating {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("How will you use Rides?").font(.system(size: 14, weight: .semibold))
                                    Picker("Account type", selection: $role) {
                                        Text("Ride").tag(DemoRole.rider)
                                        Text("Drive").tag(DemoRole.driver)
                                    }.pickerStyle(.segmented).accessibilityIdentifier("auth.role")
                                    Text("Your account type can't be changed after signup.")
                                        .font(.system(size: 13)).foregroundStyle(.secondary)
                                }
                                if role == .driver {
                                    field("Vehicle", id: .vehicle) {
                                        TextField("Make, model and color", text: $vehicle)
                                            .focused($focusedField, equals: .vehicle).submitLabel(.next)
                                            .onSubmit { focusedField = .plate }
                                            .accessibilityIdentifier("auth.vehicle")
                                    }
                                    field("License plate", id: .plate) {
                                        TextField("License plate", text: $plate)
                                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                                            .focused($focusedField, equals: .plate).submitLabel(.go)
                                            .onSubmit { submit() }.accessibilityIdentifier("auth.plate")
                                    }
                                }
                            }
                        }.disabled(store.busy)
                        if let error = store.errorMessage {
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 14)).foregroundStyle(.red)
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityIdentifier("auth.error")
                        }
                        if creating {
                            Text("Email recovery and independent driver verification aren't available yet.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 24)
                    .frame(maxWidth: 520).frame(maxWidth: .infinity, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { previous, _ in
                    if let previous { touched.insert(previous) }
                    revealFocusedField(in: scroll)
                }
                .onChange(of: geometry.size.height) { _, _ in revealFocusedField(in: scroll) }
                .onChange(of: errors) { _, _ in revealFocusedField(in: scroll) }
            }
        }
        .background(.white).tint(.black)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 16) {
                RidePrimaryButton(title: creating ? "Create account" : "Sign in", busy: store.busy, action: submit)
                    .accessibilityIdentifier("auth.submit")
                Button {
                    creating.toggle()
                    password = ""
                    showPassword = false
                    submitted = false
                    touched = []
                    store.errorMessage = nil
                    focusedField = creating ? .name : .email
                } label: {
                    HStack(spacing: 0) {
                        Text(creating ? "Already have an account? " : "New to Rides? ").foregroundStyle(.secondary)
                        Text(creating ? "Sign in" : "Create an account").bold()
                    }
                }
                .font(.system(size: 14)).foregroundStyle(.black).padding(.vertical, 4)
                .disabled(store.busy).accessibilityIdentifier("auth.switchMode")
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
            .frame(maxWidth: 520).frame(maxWidth: .infinity)
            .background(.white).overlay(alignment: .top) { Divider() }
        }
        .onChange(of: email) { _, _ in store.errorMessage = nil }
        .onChange(of: password) { _, _ in store.errorMessage = nil }
    }

    private func field<Content: View>(_ title: String, id: RideAccountField, @ViewBuilder content: () -> Content) -> some View {
        let error = submitted || touched.contains(id) || (id == .password && creating && !password.isEmpty) ? errors[id] : nil
        return VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .semibold))
            content().font(.system(size: 16)).padding(.horizontal, 16).padding(.vertical, id == .password ? 10 : 17)
                .background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(error == nil ? Color.clear : Color.red, lineWidth: 1) }
            if id == .password && creating {
                Label("Use 12–128 characters.", systemImage: password.isEmpty || errors[.password] != nil ? "info.circle" : "checkmark.circle")
                    .font(.system(size: 13)).foregroundStyle(password.isEmpty || errors[.password] != nil ? Color.secondary : RideStyle.green)
                    .accessibilityIdentifier("auth.password.requirement")
            }
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 13)).foregroundStyle(.red)
                    .accessibilityIdentifier("auth.\(id).error")
            }
        }.id(id)
    }

    private func revealFocusedField(in scroll: ScrollViewProxy) {
        guard let focusedField else { return }
        withAnimation { scroll.scrollTo(focusedField, anchor: .center) }
    }

    private func submit() {
        guard !store.busy else { return }
        submitted = true
        if let invalid = [RideAccountField.name, .email, .password, .vehicle, .plate].first(where: { errors[$0] != nil }) {
            focusedField = invalid
            return
        }
        focusedField = nil
        Task {
            let registration = creating ? RideRegistration(name: name, email: email, password: password, role: role, vehicle: role == .driver ? vehicle : nil, plate: role == .driver ? plate : nil) : nil
            if await store.signIn(email: email, password: password, registration: registration) { password = "" }
        }
    }
}
