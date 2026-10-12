import SwiftUI

/// The front door. Until someone types their own server address and proves who they
/// are, this app knows nothing and can reach nothing — there is no default host, no
/// discovery, and no demo mode.
struct PairingView: View {
    @Environment(Session.self) private var session
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var step: Step = .address
    @State private var address = ""
    @State private var resolved: URL?
    @State private var deviceName = Session.suggestedDeviceName
    @State private var username = ""
    @State private var password = ""
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @State private var signUpsOpen = false

    @FocusState private var focus: Field?

    private enum Step: Hashable { case address, method, signIn, pairingCode }
    private enum Field: Hashable { case address, username, password, code, device }

    var body: some View {
        ZStack {
            Color.mqGround.ignoresSafeArea()
            marqueeGlow

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 44)
                        .padding(.bottom, 34)

                    Group {
                        switch step {
                        case .address: addressStep
                        case .method: methodStep
                        case .signIn: signInStep
                        case .pairingCode: codeStep
                        }
                    }
                    .frame(maxWidth: 460)

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.mqSub)
                            .foregroundStyle(Color.mqVelvet)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: 460, alignment: .leading)
                            .padding(.top, 16)
                            .transition(.opacity)
                    }

                    if let reason = session.signedOutReason, step == .address {
                        Text(reason)
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                            .frame(maxWidth: 460, alignment: .leading)
                            .padding(.top, 18)
                    }

                    Spacer(minLength: 40)
                    privacyNote
                        .padding(.top, 30)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, MQ.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.snappy(duration: 0.28), value: step)
        .animation(.easeInOut(duration: 0.2), value: error)
    }

    // MARK: - Chrome

    private var marqueeGlow: some View {
        // A single soft brass wash behind the wordmark — the marquee's spill light,
        // not a gradient for its own sake.
        RadialGradient(colors: [Color.mqBrass.opacity(0.16), .clear],
                       center: .init(x: 0.5, y: 0.16),
                       startRadius: 0, endRadius: 420)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var header: some View {
        VStack(spacing: 10) {
            BulbRow(count: 9)
            Text("Marquee")
                .font(MarqueeFont.wordmark(38, relativeTo: .largeTitle))
                .foregroundStyle(Color.mqBrass)
                .tracking(2)
            Text(subtitle)
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Marquee. \(subtitle)")
    }

    private var subtitle: String {
        switch step {
        case .address: "Connect to your own Marquee server."
        case .method: "How would you like to sign in?"
        case .signIn: "Sign in to \(hostLabel)."
        case .pairingCode: "Enter the code from your Marquee web app."
        }
    }

    private var hostLabel: String { resolved?.host ?? "your server" }

    private var privacyNote: some View {
        Text("Marquee only ever talks to the server you pair it with. No analytics, no crash reporting, nothing sent anywhere else.")
            .font(.mqCaption)
            .foregroundStyle(Color.mqInkMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 400)
    }

    // MARK: - Step 1 · address

    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldLabel("Server address")
            TextField("marquee.example.com", text: $address)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focus, equals: .address)
                .onSubmit { Task { await connect() } }
                .pairingField()
                .accessibilityIdentifier("pairing.address")

            Text("Wherever you open Marquee in a browser. A hostname or an address on your home network both work — if you leave off http:// or https://, Marquee tries both.")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)

            Button {
                Task { await connect() }
            } label: {
                BusyLabel("Connect", busy: busy)
            }
            .buttonStyle(.mqPrimary)
            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            .padding(.top, 4)
            .accessibilityIdentifier("pairing.connect")
        }
        .onAppear { focus = .address }
    }

    // MARK: - Step 2 · how to sign in

    private var methodStep: some View {
        VStack(spacing: 12) {
            ConnectedChip(host: hostLabel) { back(to: .address) }
                .padding(.bottom, 6)

            MethodCard(
                title: "Use a pairing code",
                detail: "Open Marquee where you're already signed in, go to Settings › Devices, and generate a code. Your password never leaves that browser.",
                symbol: "number.circle.fill",
                emphasised: true
            ) {
                error = nil
                step = .pairingCode
            }
            .accessibilityIdentifier("pairing.method.code")

            MethodCard(
                title: "Sign in with your password",
                detail: "Your Marquee username and password, the same as the web app.",
                symbol: "person.circle.fill",
                emphasised: false
            ) {
                error = nil
                step = .signIn
            }
            .accessibilityIdentifier("pairing.method.password")

            if signUpsOpen {
                Text("This server is accepting new sign-ups, so you can also create an account from the web app.")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - Step 3a · username and password

    private var signInStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConnectedChip(host: hostLabel) { back(to: .address) }

            FieldLabel("Username")
            TextField("username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .username)
                .onSubmit { focus = .password }
                .pairingField()
                .accessibilityIdentifier("pairing.username")

            FieldLabel("Password")
            SecureField("password", text: $password)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focus, equals: .password)
                .onSubmit { Task { await signIn() } }
                .pairingField()
                .accessibilityIdentifier("pairing.password")

            deviceNameField

            Button { Task { await signIn() } } label: {
                BusyLabel("Take your seat", busy: busy)
            }
            .buttonStyle(.mqPrimary)
            .disabled(username.isEmpty || password.isEmpty || busy)
            .padding(.top, 4)
            .accessibilityIdentifier("pairing.signIn")

            Button("Use a pairing code instead") {
                error = nil
                step = .pairingCode
            }
            .buttonStyle(.mqQuiet)
            .frame(maxWidth: .infinity)
        }
        .onAppear { focus = .username }
    }

    // MARK: - Step 3b · pairing code

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConnectedChip(host: hostLabel) { back(to: .address) }

            FieldLabel("Pairing code")
            CodeField(code: $code)
                .focused($focus, equals: .code)
                .onChange(of: code) { _, new in
                    if new.count == 6 { Task { await claim() } }
                }

            Text("In Marquee on your computer or phone browser: **Settings › Devices › Pair a new device**. Codes last five minutes and work once.")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)

            deviceNameField

            Button { Task { await claim() } } label: {
                BusyLabel("Pair this device", busy: busy)
            }
            .buttonStyle(.mqPrimary)
            .disabled(code.count != 6 || busy)
            .padding(.top, 4)
            .accessibilityIdentifier("pairing.claim")

            Button("Sign in with a password instead") {
                error = nil
                step = .signIn
            }
            .buttonStyle(.mqQuiet)
            .frame(maxWidth: .infinity)
        }
        .onAppear { focus = .code }
    }

    private var deviceNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("Name this device")
            TextField("iPhone", text: $deviceName)
                .textContentType(.nickname)
                .submitLabel(.done)
                .focused($focus, equals: .device)
                .pairingField()
                .accessibilityIdentifier("pairing.deviceName")
            Text("Shown in your server's device list, so you know which one to unpair later.")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func back(to step: Step) {
        error = nil
        code = ""
        self.step = step
    }

    private func connect() async {
        error = nil
        busy = true
        defer { busy = false }
        do {
            let base = try await ServerAddress.resolve(address)
            resolved = base
            address = base.absoluteString
            signUpsOpen = await checkSignUps(base)
            focus = nil
            step = .method
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func checkSignUps(_ base: URL) async -> Bool {
        var request = URLRequest(url: base.appendingPathComponent("api/signup_open"))
        request.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.marqueeShared.data(for: request),
              let payload = try? JSONDecoder().decode(SignupOpen.self, from: data)
        else { return false }
        return payload.open
    }

    private func signIn() async {
        guard let base = resolved else { return }
        error = nil
        busy = true
        defer { busy = false }
        let body = LoginRequest(username: username.trimmingCharacters(in: .whitespaces),
                                password: password,
                                deviceName: trimmedDeviceName)
        do {
            let response: AuthResponse = try await post("api/login", body: body, to: base)
            // Signing in worked, but no token came back: this server predates the
            // native-client additions and would only ever hand out a cookie.
            guard let token = response.token else { throw APIError.needsServerUpdate }
            try adopt(base: base, token: token,
                      username: response.username ?? username,
                      displayName: response.username ?? username,
                      isAdmin: response.isAdmin ?? false)
        } catch APIError.http(let status, let detail) where status == 401 {
            error = detail.isEmpty ? "Wrong username or password." : detail
        } catch APIError.unauthorized {
            error = "Wrong username or password."
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func claim() async {
        guard let base = resolved, code.count == 6, !busy else { return }
        error = nil
        busy = true
        defer { busy = false }
        let body = ClaimRequest(code: code, deviceName: trimmedDeviceName)
        do {
            let response: AuthResponse = try await post("api/pair/claim", body: body, to: base)
            guard let token = response.token, let user = response.user else {
                throw APIError.needsServerUpdate
            }
            try adopt(base: base, token: token, username: user.username,
                      displayName: user.person.name, isAdmin: user.isAdmin ?? false,
                      person: user.person)
        } catch APIError.http(let status, _) where status == 404 {
            // The endpoint isn't there at all — an older server, not a bad code.
            // (A wrong or expired code answers 410, which falls through below.)
            code = ""
            error = APIError.needsServerUpdate.errorDescription
        } catch {
            code = ""
            focus = .code
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var trimmedDeviceName: String {
        let name = deviceName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? Session.suggestedDeviceName : name
    }

    private func adopt(base: URL, token: String, username: String, displayName: String,
                       isAdmin: Bool, person: Person? = nil) throws {
        let server = PairedServer(baseURL: base, token: token, username: username,
                                  displayName: displayName, isAdmin: isAdmin,
                                  deviceName: trimmedDeviceName)
        try session.adopt(server: server, me: person)
    }

    /// Pairing happens before there's a client, so these two calls are made by hand.
    private func post<Body: Encodable & Sendable, Result: Decodable>(
        _ path: String, body: Body, to base: URL
    ) async throws -> Result {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.marqueeShared.data(for: request)
        } catch let error as URLError {
            throw APIError.offline(error.code == .timedOut
                                   ? "The server didn't answer in time."
                                   : "Couldn't reach that server.")
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.notMarquee }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?
                .flatMap { $0["detail"] as? String } ?? ""
            throw APIError.http(status: http.statusCode,
                                detail: detail.isEmpty ? "That didn't work." : detail)
        }
        guard let decoded = try? JSONDecoder().decode(Result.self, from: data) else {
            throw APIError.decoding(String(describing: Result.self))
        }
        return decoded
    }
}

// MARK: - Request bodies

private struct LoginRequest: Encodable, Sendable {
    var username: String
    var password: String
    var deviceName: String
    /// Browsers keep using the cookie; native clients ask for the token explicitly.
    var wantToken = true

    enum CodingKeys: String, CodingKey {
        case username, password
        case deviceName = "device_name"
        case wantToken = "want_token"
    }
}

private struct ClaimRequest: Encodable, Sendable {
    var code: String
    var deviceName: String

    enum CodingKeys: String, CodingKey {
        case code
        case deviceName = "device_name"
    }
}

// MARK: - Pieces

private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).mqEyebrowStyle()
    }
}

private struct BusyLabel: View {
    let title: String
    let busy: Bool
    init(_ title: String, busy: Bool) {
        self.title = title
        self.busy = busy
    }
    var body: some View {
        HStack(spacing: 8) {
            if busy {
                ProgressView().controlSize(.small).tint(Color.mqBrassOnFill)
            }
            Text(busy ? "Connecting…" : title)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ConnectedChip: View {
    let host: String
    let change: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.mqBrass)
            Text(host)
                .font(.mqSub)
                .foregroundStyle(Color.mqInk)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button("Change", action: change)
                .font(.mqCaption)
                .foregroundStyle(Color.mqBrass)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.mqBrassSoft, in: .rect(cornerRadius: MQ.radiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connected to \(host)")
    }
}

private struct MethodCard: View {
    let title: String
    let detail: String
    let symbol: String
    let emphasised: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(emphasised ? Color.mqBrass : Color.mqInkSoft)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.mqHeadline)
                        .foregroundStyle(Color.mqInk)
                    Text(detail)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mqInkMuted)
                    .padding(.top, 4)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radius))
        .overlay(
            RoundedRectangle(cornerRadius: MQ.radius)
                .strokeBorder(emphasised ? Color.mqBrassDim : Color.mqHairline, lineWidth: 1)
        )
        .contentShape(.rect)
    }
}

/// Six digits, spaced out and read one at a time by VoiceOver. Backed by a single
/// hidden text field so the system keyboard, paste and autofill all behave.
private struct CodeField: View {
    @Binding var code: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.01)
                .onChange(of: code) { _, new in
                    let digits = new.filter(\.isNumber)
                    code = String(digits.prefix(6))
                }

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let characters = Array(code)
                    let filled = index < characters.count
                    Text(filled ? String(characters[index]) : " ")
                        .font(MarqueeFont.wordmark(26, relativeTo: .title))
                        .foregroundStyle(Color.mqBrass)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: MQ.radiusSmall)
                                .strokeBorder(filled ? Color.mqBrassDim : Color.mqHairline,
                                              lineWidth: filled ? 1.5 : 1)
                        )
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(.rect)
        .onTapGesture { focused = true }
        .accessibilityElement()
        .accessibilityLabel("Pairing code")
        .accessibilityValue(code.isEmpty ? "Empty" : code.map(String.init).joined(separator: " "))
        .accessibilityHint("Six digits from your Marquee web app")
        .accessibilityAddTraits(.isKeyboardKey)
        .onTapGesture { focused = true }
    }
}

/// The bulb row from the marquee canopy — two rows of these frame the wordmark on the
/// pairing screen and the celebration card.
struct BulbRow: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(Color.mqBrassBright)
                    .frame(width: 5, height: 5)
                    .opacity(reduceMotion ? 0.55 : (index % 2 == phase ? 1 : 0.28))
                    .shadow(color: Color.mqBrass.opacity(0.6), radius: 4)
            }
        }
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            // Chasing bulbs: the whole row alternates rather than each bulb animating
            // on its own timer, which keeps this to one state change a second.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(620))
                withAnimation(.easeInOut(duration: 0.3)) { phase = 1 - phase }
            }
        }
    }
}

private extension View {
    func pairingField() -> some View {
        self.font(.mqBody)
            .foregroundStyle(Color.mqInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: MQ.radiusSmall)
                    .strokeBorder(Color.mqHairline, lineWidth: 1)
            )
    }
}
