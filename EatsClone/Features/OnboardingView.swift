import SwiftUI

struct LocalOnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 0
    @State private var contact = "alex@example.com"
    @State private var code = ""
    @State private var name = "Alex Morgan"
    @State private var address = "425 Market St, San Francisco"
    @State private var error = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                if step > 0 { Button { step -= 1; error = false } label: { Image(systemName: "arrow.left").font(.title3) }.accessibilityLabel("Previous step") }
                Spacer()
                Text("LOCAL DEMO").font(.caption.weight(.bold)).tracking(2).foregroundStyle(EatsTheme.green)
                Spacer()
                Button("Skip") { store.snapshot.onboarded = true }.font(.subheadline)
            }
            HStack(spacing: 6) { ForEach(0..<4, id: \.self) { index in Capsule().fill(index <= step ? EatsTheme.green : EatsTheme.gray).frame(height: 4) } }
            Group {
                switch step {
                case 0:
                    Text("What’s your email?").font(.largeTitle.bold()).tracking(-1)
                    Text("Create a local demo profile to make this app your own.").foregroundStyle(.secondary)
                    TextField("Email address", text: $contact).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().onSubmit { next() }
                        .padding(18).background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 8))
                    Label("No email is sent. Use sample details only.", systemImage: "envelope.badge.shield.half.filled").font(.footnote).foregroundStyle(.secondary)
                case 1:
                    Text("Enter your demo code").font(.largeTitle.bold()).tracking(-1)
                    Text("This verification is simulated. Enter 1234 to continue.").foregroundStyle(.secondary)
                    TextField("1234", text: $code).keyboardType(.numberPad).font(.system(size: 36, weight: .bold, design: .monospaced)).tracking(16)
                        .padding(18).background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 8))
                    Button("Fill demo code") { code = "1234" }.font(.subheadline.bold())
                case 2:
                    Text("What’s your name?").font(.largeTitle.bold()).tracking(-1)
                    Text("Let us know how to address you.").foregroundStyle(.secondary)
                    TextField("Your name", text: $name).textContentType(.nickname).onSubmit { next() }.padding(18).background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 8))
                default:
                    LocalMapView().frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 18))
                    Text("Find food near you").font(.largeTitle.bold()).tracking(-1)
                    TextField("Delivery address", text: $address).textContentType(.fullStreetAddress).padding(18).background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 8))
                    Text("Location and address lookup stay offline. This is sample delivery data.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if error { Text(step == 1 ? "Enter the demo code 1234." : "Please enter a valid \(step == 0 ? "email address" : step == 2 ? "name" : "address").").font(.footnote).foregroundStyle(.red) }
            Spacer(minLength: 12)
            BlackButton(title: step == 3 ? "Start exploring" : "Continue") { next() }
        }.padding(24).padding(.top, 12).background(.white)
    }

    private func next() {
        let valid: Bool
        switch step {
        case 0: valid = contact.contains("@") && contact.contains(".")
        case 1: valid = code == "1234"
        case 2: valid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: valid = !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard valid else { error = true; return }
        error = false
        if step < 3 { step += 1 } else {
            store.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            store.profile.email = contact.trimmingCharacters(in: .whitespacesAndNewlines)
            store.profile.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
            store.snapshot.onboarded = true
        }
    }
}
