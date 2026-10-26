import PlantekalenderKit
import SwiftUI

struct LoginView: View {
    @State private var model: LoginModel

    init(api: AuthAPI, session: SessionStore) {
        _model = State(initialValue: LoginModel(api: api, session: session))
    }

    var body: some View {
        Form {
            Section {
                TextField("E-mail", text: $model.email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("Adgangskode", text: $model.password)
                    .textContentType(model.registering ? .newPassword : .password)
            } header: {
                Text(model.registering ? "Opret en konto" : "Log ind")
            } footer: {
                if let error = model.error { Text(error).foregroundStyle(.red) }
            }
            Button(model.registering ? "Opret konto" : "Log ind") { Task { await model.submit() } }
                .disabled(model.busy)
            Button(model.registering ? "Har du en konto? Log ind" : "Ny bruger? Opret en konto") {
                model.registering.toggle()
            }
        }
        .navigationTitle("Plantekalender")
    }
}
