#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif
import Foundation
import ImageIO

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// Apple Intelligence (Foundation Models) for Genkit, over Pigeon. The Dart
/// side (`defineAppleIntelligenceModel`) turns Genkit requests into
/// `AppleGenerateRequest`s and these answers back into model responses.
///
/// Version gates, from the #183 spike:
/// - iOS / macOS 26: the model at all.
/// - 26.4: `contextSize` and `tokenCount(for:)`.
/// - 27: image input, `response.usage` and `capabilities`.
/// `#if compiler(...)` keeps each newer API out of builds with an older SDK,
/// where `#available` alone wouldn't compile.
public class GenkitAppleIntelligencePlugin: NSObject, FlutterPlugin, AppleIntelligenceHostApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    AppleIntelligenceHostApiSetup.setUp(binaryMessenger: messenger, api: GenkitAppleIntelligencePlugin())
  }

  // MARK: Status

  func status() throws -> AppleModelStatus {
    let os = ProcessInfo.processInfo.operatingSystemVersion
    let version = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *) {
        let model = SystemLanguageModel.default
        let availability: AppleModelAvailability
        switch model.availability {
        case .available: availability = .available
        case .unavailable(.deviceNotEligible): availability = .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): availability = .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady): availability = .modelNotReady
        case .unavailable: availability = .unavailable
        }
        return AppleModelStatus(
          availability: availability,
          contextSize: Self.contextSize(),
          supportsImages: Self.supportsImages(),
          osVersion: version
        )
      }
    #endif
    return AppleModelStatus(availability: .unsupportedOS, contextSize: nil, supportsImages: false, osVersion: version)
  }

  private static func contextSize() -> Int64? {
    #if canImport(FoundationModels) && compiler(>=6.3)
      if #available(iOS 26.4, macOS 26.4, *) { return Int64(SystemLanguageModel.default.contextSize) }
    #endif
    return nil
  }

  private static func supportsImages() -> Bool {
    #if canImport(FoundationModels) && compiler(>=6.4)
      if #available(iOS 27.0, macOS 27.0, *) {
        return SystemLanguageModel.default.capabilities.contains(.vision)
      }
    #endif
    return false
  }

  // MARK: Token counts

  func countTokens(text: String) async throws -> Int64? {
    #if canImport(FoundationModels) && compiler(>=6.3)
      if #available(iOS 26.4, macOS 26.4, *) {
        return Int64(try await SystemLanguageModel.default.tokenCount(for: Prompt(text)))
      }
    #endif
    return nil
  }

  // MARK: Generation

  func generate(request: AppleGenerateRequest) async throws -> AppleGenerateResponse {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *) {
        do {
          return try await AppleGeneration(request).run()
        } catch let error as PigeonError {
          throw error
        } catch {
          throw PigeonError(code: Self.errorCode(error), message: "\(error)", details: nil)
        }
      }
    #endif
    throw PigeonError(code: "unsupported", message: "Apple Intelligence needs iOS or macOS 26", details: nil)
  }

  /// One code per error the Dart side handles differently.
  static func errorCode(_ error: Error) -> String {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *), let e = error as? LanguageModelSession.GenerationError {
        switch e {
        case .exceededContextWindowSize: return "tooLong"
        case .guardrailViolation, .refusal: return "refused"
        case .unsupportedLanguageOrLocale: return "unsupportedLanguage"
        case .rateLimited, .concurrentRequests: return "rateLimited"
        case .assetsUnavailable: return "unavailable"
        default: return "failed"
        }
      }
    #endif
    let s = "\(error)"
    if s.contains("exceededContextWindowSize") || s.contains("exceeds") { return "tooLong" }
    if s.contains("guardrailViolation") || s.contains("refusal") { return "refused" }
    return "failed"
  }
}

#if canImport(FoundationModels)
  /// One request, in one fresh session: nothing carries over between calls.
  @available(iOS 26.0, macOS 26.0, *)
  struct AppleGeneration {
    let request: AppleGenerateRequest

    init(_ request: AppleGenerateRequest) { self.request = request }

    func run() async throws -> AppleGenerateResponse {
      var options = GenerationOptions()
      if let t = request.temperature { options.temperature = t }
      options.maximumResponseTokens = Int(request.maximumResponseTokens)

      var schema: GenerationSchema?
      var gaps: [String] = []
      if let schemaJson = request.schemaJson {
        guard let data = schemaJson.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw PigeonError(code: "schemaUnsupported", message: "Not a JSON object", details: nil) }
        let converter = SchemaConverter()
        do {
          schema = try converter.convertRoot(json)
        } catch {
          throw PigeonError(code: "schemaUnsupported", message: "\(error)", details: converter.gaps)
        }
        if converter.unsupported {
          throw PigeonError(code: "schemaUnsupported", message: converter.gaps.joined(separator: "; "), details: nil)
        }
        gaps = converter.gaps
      }

      let session = LanguageModelSession(instructions: request.instructions ?? "")
      let prompt = request.prompt

      if let image = request.image?.data {
        #if compiler(>=6.4)
          if #available(iOS 27.0, macOS 27.0, *) {
            guard let source = CGImageSourceCreateWithData(image as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { throw PigeonError(code: "badImage", message: "The image couldn't be decoded", details: nil) }
            if let schema {
              let r = try await session.respond(schema: schema, options: options) { prompt; Attachment(cg) }
              return response(r.content.jsonString, gaps, Int64(r.usage.input.totalTokenCount), Int64(r.usage.output.totalTokenCount))
            }
            let r = try await session.respond(options: options) { prompt; Attachment(cg) }
            return response(r.content, gaps, Int64(r.usage.input.totalTokenCount), Int64(r.usage.output.totalTokenCount))
          }
        #endif
        throw PigeonError(code: "unsupported", message: "Image input needs iOS or macOS 27", details: nil)
      }

      #if compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, *) {
          if let schema {
            let r = try await session.respond(to: prompt, schema: schema, options: options)
            return response(r.content.jsonString, gaps, Int64(r.usage.input.totalTokenCount), Int64(r.usage.output.totalTokenCount))
          }
          let r = try await session.respond(to: prompt, options: options)
          return response(r.content, gaps, Int64(r.usage.input.totalTokenCount), Int64(r.usage.output.totalTokenCount))
        }
      #endif

      // iOS / macOS 26: no usage on the response, so count what can be
      // counted (26.4 and later).
      let text: String
      if let schema {
        text = try await session.respond(to: prompt, schema: schema, options: options).content.jsonString
      } else {
        text = try await session.respond(to: prompt, options: options).content
      }
      let input = await count(prompt, instructions: request.instructions)
      let output = await count(text)
      return response(text, gaps, input, output)
    }

    private func response(_ text: String, _ gaps: [String], _ input: Int64?, _ output: Int64?) -> AppleGenerateResponse {
      AppleGenerateResponse(text: text, inputTokens: input, outputTokens: output, schemaGaps: gaps)
    }

    private func count(_ text: String, instructions: String? = nil) async -> Int64? {
      #if compiler(>=6.3)
        if #available(iOS 26.4, macOS 26.4, *) {
          let model = SystemLanguageModel.default
          guard let prompt = try? await model.tokenCount(for: Prompt(text)) else { return nil }
          var total = prompt
          if let instructions, let i = try? await model.tokenCount(for: Instructions(instructions)) { total += i }
          return Int64(total)
        }
      #endif
      return nil
    }
  }
#endif
