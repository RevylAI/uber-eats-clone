import SwiftUI

struct DemoConnectionView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    @State private var joinExisting = false
    @State private var copied = false
    @State private var confirmLeave = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: "iphone").font(.system(size: 36))
                        Image(systemName: "arrow.left.arrow.right").font(.system(size: 20))
                        Image(systemName: "iphone").font(.system(size: 36))
                    }.padding(.top, 10)
                    Text(store.connected ? "Your shared demo" : "One ride. Two phones.").font(.system(size: 31, weight: .bold))
                    Text("Create a room on the rider phone. On the driver phone, choose Driver and join with the same server address and invitation code.").font(.subheadline).foregroundStyle(.secondary)
                    if let session = store.credentials {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("\(session.name) · \(session.role.title)", systemImage: session.role == .rider ? "person.fill" : "car.fill").font(.headline)
                            Text("Invitation code").font(.caption).foregroundStyle(.secondary)
                            Text(session.roomCode).font(.system(size: 30, weight: .bold, design: .monospaced)).tracking(3).textSelection(.enabled)
                            Text(session.baseURL.absoluteString).font(.caption).textSelection(.enabled)
                            Button(copied ? "Copied invitation" : "Copy invitation") {
                                UIPasteboard.general.string = "Rides demo\nServer: \(session.baseURL.absoluteString)\nRoom: \(session.roomCode)\nChoose Driver to join. Keep this invitation private."
                                copied = true
                            }.font(.subheadline.bold())
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 14))
                        RidePrimaryButton(title: "Continue as \(session.role.title)") { dismiss() }
                        Button("Leave this demo", role: .destructive) { confirmLeave = true }.disabled(store.activeTrip != nil)
                        if store.activeTrip != nil { Text("Finish or cancel the active ride before leaving.").font(.caption).foregroundStyle(.secondary) }
                    } else {
                        HStack(spacing: 12) {
                            ForEach(DemoRole.allCases) { role in
                                Button { store.chooseRole(role) } label: {
                                    VStack(spacing: 9) {
                                        Image(systemName: role == .rider ? "person.crop.circle.fill" : "car.side.fill").font(.system(size: 30))
                                        Text(role.title).font(.headline)
                                    }.frame(maxWidth: .infinity).padding(18).background(store.role == role ? Color.black : RideStyle.soft).foregroundStyle(store.role == role ? Color.white : Color.black).clipShape(RoundedRectangle(cornerRadius: 12))
                                }.disabled(store.busy)
                            }
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Demo server").font(.subheadline.bold())
                            TextField("https://your-demo-server", text: $store.serverAddress).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().padding(14).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 9)).accessibilityIdentifier("demo.server")
                            Text("The server must be reachable by both phones. No public server is bundled.").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Your demo name").font(.subheadline.bold())
                            TextField("Name", text: $store.displayName).textContentType(.name).padding(14).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        if store.role == .rider { Toggle("Join an existing room", isOn: $joinExisting).tint(.black) }
                        if store.role == .driver || joinExisting {
                            TextField("Invitation code", text: $store.roomInput).textInputAutocapitalization(.characters).autocorrectionDisabled().padding(14).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 9)).accessibilityIdentifier("demo.room")
                        }
                        if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                        RidePrimaryButton(title: store.role == .rider && !joinExisting ? "Create rider room" : "Join as \(store.role.title)", busy: store.busy, disabled: store.serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                            Task {
                                await store.connect(createNew: store.role == .rider && !joinExisting)
                                if store.connected && (store.role == .driver || joinExisting) { dismiss() }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("A shared demo, not a real ride", systemImage: "info.circle").font(.subheadline.bold())
                        Text("Trip requests, acceptance, messages, and ride progress sync through your server. Maps, fares, profiles, and payment methods are sample data. Anyone with the private invitation can join this room.").font(.caption).foregroundStyle(.secondary)
                    }.padding(.bottom, 20)
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively)
                .navigationTitle("Demo connection").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.disabled(store.busy) } }
                .confirmationDialog("Leave this demo?", isPresented: $confirmLeave, titleVisibility: .visible) {
                    Button("Leave demo", role: .destructive) { store.disconnect() }
                } message: { Text("The room and its trip history stay on the server until the room expires. Keep the invitation to rejoin as the rider.") }
        }.tint(.black)
    }
}
