import Foundation

struct UnsplashPhoto {
    let id: String
    let imageURL: URL
    let photographer: String
    let photographerURL: String
}

class UnsplashService {

    func fetchRandomPhoto(completion: @escaping (Result<UnsplashPhoto, Error>) -> Void) {
        let apiKey = Preferences.shared.apiKey
        guard !apiKey.isEmpty else {
            completion(.failure(WallSpanError.noAPIKey))
            return
        }

        let terms = Preferences.shared.searchTerms
        guard let query = terms.randomElement()?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(WallSpanError.noSearchTerms))
            return
        }

        // Auto-detect orientation based on screen arrangement
        let orientation = ScreenGeometry.orientation()
        let orientationParam = orientation == "squarish" ? "squarish" : orientation
        let urlString = "https://api.unsplash.com/photos/random?query=\(query)&orientation=\(orientationParam)&content_filter=high"
        guard let url = URL(string: urlString) else {
            completion(.failure(WallSpanError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Client-ID \(apiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                completion(.failure(WallSpanError.apiError(statusCode: httpResponse.statusCode, message: body)))
                return
            }

            guard let data = data else {
                completion(.failure(WallSpanError.noData))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let urls = json["urls"] as? [String: Any],
                      let rawURL = urls["raw"] as? String,
                      let user = json["user"] as? [String: Any],
                      let name = user["name"] as? String,
                      let links = user["links"] as? [String: Any],
                      let htmlLink = links["html"] as? String,
                      let id = json["id"] as? String
                else {
                    completion(.failure(WallSpanError.parseError))
                    return
                }

                // Request full resolution image with maximum quality
                let dims = ScreenGeometry.combinedDimensions()
                let maxDim = max(dims.width, dims.height)
                let imageURLString = rawURL + "&w=\(maxDim)&q=100&fm=jpg"
                guard let imageURL = URL(string: imageURLString) else {
                    completion(.failure(WallSpanError.invalidURL))
                    return
                }

                let photo = UnsplashPhoto(
                    id: id,
                    imageURL: imageURL,
                    photographer: name,
                    photographerURL: htmlLink
                )
                completion(.success(photo))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

enum WallSpanError: LocalizedError {
    case noAPIKey
    case noSearchTerms
    case invalidURL
    case noData
    case parseError
    case apiError(statusCode: Int, message: String)
    case imageProcessingFailed
    case noScreens

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No Unsplash API key. Open Preferences to set one."
        case .noSearchTerms:
            return "No search terms configured."
        case .invalidURL:
            return "Failed to construct URL."
        case .noData:
            return "No data received from Unsplash."
        case .parseError:
            return "Failed to parse Unsplash response."
        case .apiError(let code, let message):
            return "Unsplash API error (\(code)): \(message)"
        case .imageProcessingFailed:
            return "Failed to process image."
        case .noScreens:
            return "No screens detected."
        }
    }
}
