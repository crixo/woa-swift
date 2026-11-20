import Foundation

/// Sends email through the Gmail API using the stored Google OAuth token.
/// Requires the `gmail.send` scope (requested by `GoogleAuthConfig.scopes`).
struct GmailService {

    enum GmailError: LocalizedError {
        case scopeNotGranted
        case invalidRecipient
        case api(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .scopeNotGranted:
                return "The Gmail send permission was not granted. Sign in again and accept it."
            case .invalidRecipient:
                return "At least one valid recipient is required."
            case .api(let status, let message):
                return "Gmail API error \(status): \(message)"
            }
        }
    }

    let auth: GoogleAuthService

    /// Sends a plain-text or HTML email from the signed-in Google account.
    /// - Returns: the Gmail message id.
    @discardableResult
    func send(
        to recipients: [String],
        subject: String,
        body: String,
        isHTML: Bool = false,
        cc: [String] = [],
        bcc: [String] = []
    ) async throws -> String {
        guard await auth.hasGmailSendScope else { throw GmailError.scopeNotGranted }

        let to = recipients.map(Self.clean).filter { !$0.isEmpty }
        guard !to.isEmpty else { throw GmailError.invalidRecipient }

        let mime = Self.buildMIME(
            to: to,
            cc: cc.map(Self.clean).filter { !$0.isEmpty },
            bcc: bcc.map(Self.clean).filter { !$0.isEmpty },
            subject: subject,
            body: body,
            isHTML: isHTML
        )

        let token = try await auth.freshAccessToken()

        var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["raw": Self.base64URL(mime)])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(status) else {
            throw GmailError.api(status: status, message: Self.errorMessage(from: data))
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? String ?? ""
    }

    // MARK: MIME

    private static func buildMIME(to: [String], cc: [String], bcc: [String],
                                  subject: String, body: String, isHTML: Bool) -> Data {
        var lines: [String] = []
        lines.append("To: \(to.joined(separator: ", "))")
        if !cc.isEmpty { lines.append("Cc: \(cc.joined(separator: ", "))") }
        if !bcc.isEmpty { lines.append("Bcc: \(bcc.joined(separator: ", "))") }
        lines.append("Subject: \(encodeHeader(subject))")
        lines.append("MIME-Version: 1.0")
        lines.append("Content-Type: \(isHTML ? "text/html" : "text/plain"); charset=UTF-8")
        lines.append("Content-Transfer-Encoding: base64")
        lines.append("")
        lines.append(Data(body.utf8).base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed]))
        return Data(lines.joined(separator: "\r\n").utf8)
    }

    /// RFC 2047 encoding so non-ASCII subjects (accents, emoji) survive. Also strips CR/LF (header injection).
    private static func encodeHeader(_ value: String) -> String {
        let singleLine = clean(value)
        if singleLine.allSatisfy({ $0.isASCII }) { return singleLine }
        return "=?UTF-8?B?\(Data(singleLine.utf8).base64EncodedString())?="
    }

    private static func clean(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}
