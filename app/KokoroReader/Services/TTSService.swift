import Foundation

final class TTSService {
    static let shared = TTSService()
    private let session = URLSession.shared
    private let settings = SettingsService.shared
    private let maxChunkSize = 4500

    func synthesize(text: String, voice: String? = nil, speed: Double? = nil) async throws -> Data {
        guard text.count <= 5000 else { throw TTSError.textTooLong }

        let request = TTSRequest(
            text: text,
            voice: voice ?? settings.voice,
            speed: speed ?? settings.speed
        )
        return try await postTTS(request)
    }

    func synthesizeChunked(text: String, voice: String? = nil, speed: Double? = nil) async throws -> [Data] {
        let chunks = splitIntoParagraphs(text)
        var results: [Data] = []

        for chunk in chunks {
            let request = TTSRequest(
                text: chunk,
                voice: voice ?? settings.voice,
                speed: speed ?? settings.speed
            )
            let data = try await postTTS(request)
            results.append(data)
        }

        return results
    }

    func fetchVoices() async throws -> [String] {
        let url = try buildURL(path: "/api/voices")
        var request = URLRequest(url: url)
        addAuth(&request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw TTSError.serverUnreachable }
        guard httpResponse.statusCode == 200 else { throw TTSError.invalidResponse(httpResponse.statusCode) }

        let voicesResponse = try JSONDecoder().decode(VoicesResponse.self, from: data)
        return voicesResponse.voices
    }

    func checkHealth() async throws -> HealthResponse {
        let url = try buildURL(path: "/api/health")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        addAuth(&request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TTSError.serverUnreachable
        }
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    // MARK: - Private

    private func postTTS(_ ttsRequest: TTSRequest) async throws -> Data {
        let url = try buildURL(path: "/api/tts")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuth(&request)

        guard let body = try? JSONEncoder().encode(ttsRequest) else {
            throw TTSError.encodingError
        }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw TTSError.serverUnreachable }
        guard httpResponse.statusCode == 200 else { throw TTSError.invalidResponse(httpResponse.statusCode) }
        guard !data.isEmpty else { throw TTSError.noData }

        return data
    }

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: settings.serverURL + path) else {
            throw TTSError.serverUnreachable
        }
        return url
    }

    private func addAuth(_ request: inout URLRequest) {
        // No auth needed for local server
    }

    private func splitIntoParagraphs(_ text: String) -> [String] {
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var chunks: [String] = []
        var current = ""

        for paragraph in paragraphs {
            if current.count + paragraph.count + 2 > maxChunkSize {
                if !current.isEmpty {
                    chunks.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                if paragraph.count > maxChunkSize {
                    // Split long paragraphs by sentence
                    let sentences = paragraph.components(separatedBy: ". ")
                    current = ""
                    for sentence in sentences {
                        if current.count + sentence.count + 2 > maxChunkSize {
                            if !current.isEmpty { chunks.append(current.trimmingCharacters(in: .whitespacesAndNewlines)) }
                            current = sentence
                        } else {
                            current += (current.isEmpty ? "" : ". ") + sentence
                        }
                    }
                } else {
                    current = paragraph
                }
            } else {
                current += (current.isEmpty ? "" : "\n\n") + paragraph
            }
        }
        if !current.isEmpty {
            chunks.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return chunks.isEmpty ? [text] : chunks
    }
}
