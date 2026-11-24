import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    OnDeviceLlm.register(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

// MARK: - SPIKE (#183): on-device LLM bridge to Apple Foundation Models.
// A MethodChannel for the spike; production would use Pigeon.
import FoundationModels
import ImageIO
import Vision

struct BridgeError: Error { let code: String; let message: String }

enum OnDeviceLlm {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "nomorex/on_device_llm", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "status":
        result(status())
      case "generate":
        guard #available(iOS 26.0, macOS 26.0, *) else {
          result(FlutterError(code: "unsupported", message: "Needs iOS/macOS 26", details: nil)); return
        }
        Task {
          do { result(try await generate(args)) } catch let e as BridgeError { result(FlutterError(code: e.code, message: e.message, details: nil)) } catch {
            result(FlutterError(code: errorCode(error), message: "\(error)", details: nil))
          }
        }
      case "docOcr":
        guard let data = (args["image"] as? FlutterStandardTypedData)?.data else {
          result(FlutterError(code: "badImage", message: "No image", details: nil)); return
        }
        guard #available(iOS 26.0, macOS 26.0, *) else {
          result(FlutterError(code: "unsupported", message: "Needs iOS/macOS 26", details: nil)); return
        }
        Task { result(await docOcr(data)) }
      case "ocr":
        guard let data = (args["image"] as? FlutterStandardTypedData)?.data else {
          result(FlutterError(code: "badImage", message: "No image", details: nil)); return
        }
        DispatchQueue.global(qos: .userInitiated).async { result(ocr(data)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func status() -> [String: Any] {
    var out: [String: Any] = [:]
    let os = ProcessInfo.processInfo.operatingSystemVersion
    out["os"] = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    guard #available(iOS 26.0, macOS 26.0, *) else { out["state"] = "unsupportedOS"; return out }
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available: out["state"] = "available"
    case .unavailable(.deviceNotEligible): out["state"] = "deviceNotEligible"
    case .unavailable(.appleIntelligenceNotEnabled): out["state"] = "appleIntelligenceNotEnabled"
    case .unavailable(.modelNotReady): out["state"] = "modelNotReady"
    case .unavailable(let other): out["state"] = "unavailable:\(other)"
    }
    if #available(iOS 26.4, macOS 26.4, *) { out["contextSize"] = model.contextSize }
    if #available(iOS 27.0, macOS 27.0, *) {
      out["vision"] = model.capabilities.contains(.vision)
      out["guidedGeneration"] = model.capabilities.contains(.guidedGeneration)
      out["reasoning"] = model.capabilities.contains(.reasoning)
      out["toolCalling"] = model.capabilities.contains(.toolCalling)
    }
    return out
  }



  /// iOS/macOS 26 document recognition: tables keep empty cells, so columns stay aligned.
  @available(iOS 26.0, macOS 26.0, *)
  static func docOcr(_ data: Data) async -> Any {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
      return FlutterError(code: "badImage", message: "Couldn't decode image", details: nil)
    }
    let start = Date()
    do {
      var req = RecognizeDocumentsRequest()
      req.textRecognitionOptions.useLanguageCorrection = false
      req.textRecognitionOptions.minimumTextHeightFraction = 0.004
      req.textRecognitionOptions.automaticallyDetectLanguage = false
      req.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "en-US")]
      let docs = try await req.perform(on: img)
      var lines: [String] = []
      var tableCount = 0
      for d in docs {
        if let t = d.document.title?.transcript { lines.append(t) }
        for table in d.document.tables {
          tableCount += 1
          for row in table.rows {
            lines.append(row.map { $0.content.text.transcript.replacingOccurrences(of: "\n", with: " ") }.joined(separator: " | "))
          }
        }
        if d.document.tables.isEmpty { lines.append(d.document.text.transcript) }
      }
      return ["text": lines.joined(separator: "\n"), "tables": tableCount, "ms": Int(Date().timeIntervalSince(start) * 1000)]
    } catch {
      return FlutterError(code: "ocrFailed", message: "\(error)", details: nil)
    }
  }

  /// Vision OCR, regrouped into rows (cells on the same line joined with " | ").
  static func ocr(_ data: Data) -> Any {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
      return FlutterError(code: "badImage", message: "Couldn't decode image", details: nil)
    }
    let start = Date()
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = false
    req.minimumTextHeight = 0.004
    req.recognitionLanguages = ["en-US"]
    if #available(macOS 13.0, iOS 16.0, *) { req.automaticallyDetectsLanguage = false }
    do { try VNImageRequestHandler(cgImage: img).perform([req]) } catch {
      return FlutterError(code: "ocrFailed", message: "\(error)", details: nil)
    }
    let obs = (req.results ?? []).compactMap { o -> (CGRect, String)? in
      guard let t = o.topCandidates(1).first?.string else { return nil }
      return (o.boundingBox, t)
    }.sorted { $0.0.midY > $1.0.midY }
    var rows: [[(CGRect, String)]] = []
    for o in obs {
      if var last = rows.last, let ref = last.first, abs(ref.0.midY - o.0.midY) < ref.0.height * 0.6 {
        last.append(o); rows[rows.count - 1] = last
      } else { rows.append([o]) }
    }
    let text = rows.map { $0.sorted { $0.0.minX < $1.0.minX }.map { $0.1 }.joined(separator: " | ") }.joined(separator: "\n")
    return ["text": text, "ms": Int(Date().timeIntervalSince(start) * 1000)]
  }

  static func errorCode(_ error: Error) -> String {
    let s = "\(error)"
    if s.contains("exceededContextWindowSize") || s.contains("contextSizeExceeded") { return "tooLong" }
    if s.contains("guardrailViolation") || s.contains("refusal") { return "refused" }
    if s.contains("unsupportedLanguage") { return "unsupportedLanguage" }
    if s.contains("rateLimited") || s.contains("concurrentRequests") { return "rateLimited" }
    return "failed"
  }

  @available(iOS 26.0, macOS 26.0, *)
  static func generate(_ args: [String: Any]) async throws -> [String: Any] {
    let system = args["system"] as? String
    let prompt = args["prompt"] as? String ?? ""
    let schemaJson = args["schema"] as? String
    let image = (args["image"] as? FlutterStandardTypedData)?.data
    var options = GenerationOptions()
    if let t = args["temperature"] as? Double { options.temperature = t }
    if let m = args["maxTokens"] as? Int { options.maximumResponseTokens = m }

    let session = LanguageModelSession(instructions: system ?? "")
    var out: [String: Any] = [:]
    var gaps: [String] = []
    var schema: GenerationSchema? = nil
    if let schemaJson, let data = schemaJson.data(using: .utf8),
       let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
      let conv = SchemaConverter()
      schema = try conv.convertRoot(json)
      gaps = conv.gaps
      out["schemaGaps"] = gaps
    }

    var cg: CGImage? = nil
    if let image {
      guard #available(iOS 27.0, macOS 27.0, *) else {
        throw BridgeError(code: "unsupported", message: "Image input needs iOS/macOS 27")
      }
      guard let src = CGImageSourceCreateWithData(image as CFData, nil),
            let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        throw BridgeError(code: "badImage", message: "Couldn't decode image")
      }
      cg = img
      out["imageSize"] = "\(img.width)x\(img.height)"
    }

    // Pre-count (iOS 26.4+): prompt text and schema.
    if #available(iOS 26.4, macOS 26.4, *) {
      let model = SystemLanguageModel.default
      out["promptTextTokens"] = try? await model.tokenCount(for: Prompt(prompt))
      if let system { out["instructionTokens"] = try? await model.tokenCount(for: Instructions(system)) }
      if let schema { out["schemaTokens"] = try? await model.tokenCount(for: schema) }
    }

    let start = Date()
    if #available(iOS 27.0, macOS 27.0, *) {
      if let schema {
        let r: LanguageModelSession.Response<GeneratedContent>
        if let cg {
          r = try await session.respond(schema: schema, options: options) { prompt; Attachment(cg) }
        } else {
          r = try await session.respond(to: prompt, schema: schema, options: options)
        }
        out["text"] = r.content.jsonString
        out["inputTokens"] = r.usage.input.totalTokenCount
        out["outputTokens"] = r.usage.output.totalTokenCount
      } else {
        let r: LanguageModelSession.Response<String>
        if let cg {
          r = try await session.respond(options: options) { prompt; Attachment(cg) }
        } else {
          r = try await session.respond(to: prompt, options: options)
        }
        out["text"] = r.content
        out["inputTokens"] = r.usage.input.totalTokenCount
        out["outputTokens"] = r.usage.output.totalTokenCount
      }
    } else {
      if let schema {
        let r = try await session.respond(to: prompt, schema: schema, options: options)
        out["text"] = r.content.jsonString
      } else {
        out["text"] = try await session.respond(to: prompt, options: options).content
      }
    }
    out["ms"] = Int(Date().timeIntervalSince(start) * 1000)
    return out
  }
}

/// JSON Schema (as Genkit/schemantic emit it) -> DynamicGenerationSchema.
/// Records every keyword it has to drop in `gaps`.
@available(iOS 26.0, macOS 26.0, *)
final class SchemaConverter {
  var gaps: [String] = []
  private var deps: [DynamicGenerationSchema] = []
  private var counter = 0
  private let handled: Set<String> = ["type", "properties", "required", "items", "enum", "description",
                                      "minItems", "maxItems", "$defs", "$ref", "anyOf", "title",
                                      "additionalProperties", "minimum", "maximum"]

  func convertRoot(_ json: [String: Any]) throws -> GenerationSchema {
    if let defs = json["$defs"] as? [String: Any] {
      for (name, def) in defs { if let d = def as? [String: Any] { deps.append(convert(d, name: name, exactName: true, path: "$defs." + name)) } }
    }
    let root = convert(json, name: "Root")
    return try GenerationSchema(root: root, dependencies: deps)
  }

  private func nextName(_ base: String) -> String { counter += 1; return "\(base)_\(counter)" }

  func convert(_ s: [String: Any], name: String, exactName: Bool = false, path: String = "$") -> DynamicGenerationSchema {
    for k in s.keys where !handled.contains(k) { gaps.append("\(path): dropped '\(k)'") }
    if let ref = s["$ref"] as? String {
      return DynamicGenerationSchema(referenceTo: String(ref.split(separator: "/").last ?? ""))
    }
    if let any = s["anyOf"] as? [[String: Any]] {
      let nonNull = any.filter { ($0["type"] as? String) != "null" }
      if nonNull.count == 1 { gaps.append("\(path): nullable anyOf -> optional"); return convert(nonNull[0], name: name, path: path) }
      return DynamicGenerationSchema(name: nextName(name), anyOf: nonNull.map { convert($0, name: name, path: path + "|") })
    }
    var type = s["type"] as? String
    if let types = s["type"] as? [String] {
      let nonNull = types.filter { $0 != "null" }
      gaps.append("\(path): type \(types) -> \(nonNull.first ?? "string")")
      type = nonNull.first
    }
    let desc = s["description"] as? String
    switch type {
    case "object":
      let props = s["properties"] as? [String: Any] ?? [:]
      let required = Set(s["required"] as? [String] ?? [])
      if s["additionalProperties"] != nil, props.isEmpty { gaps.append("\(path): free-form map not supported") }
      let ps = props.keys.sorted().map { key -> DynamicGenerationSchema.Property in
        let p = props[key] as? [String: Any] ?? [:]
        return .init(name: key, description: p["description"] as? String,
                     schema: convert(p, name: name + "_" + key, path: path + "." + key),
                     isOptional: !required.contains(key))
      }
      return DynamicGenerationSchema(name: exactName ? name : nextName(name), description: desc, properties: ps)
    case "array":
      let items = s["items"] as? [String: Any] ?? ["type": "string"]
      return DynamicGenerationSchema(arrayOf: convert(items, name: name + "_item", path: path + "[]"),
                                     minimumElements: s["minItems"] as? Int, maximumElements: s["maxItems"] as? Int)
    case "string":
      if let e = s["enum"] as? [String] { return DynamicGenerationSchema(name: nextName(name), description: desc, anyOf: e) }
      return DynamicGenerationSchema(type: String.self)
    case "integer":
      var g: [GenerationGuide<Int>] = []
      if let lo = s["minimum"] as? Int { g.append(.minimum(lo)) }
      if let hi = s["maximum"] as? Int { g.append(.maximum(hi)) }
      return DynamicGenerationSchema(type: Int.self, guides: g)
    case "number":
      var g: [GenerationGuide<Double>] = []
      if let lo = s["minimum"] as? Double { g.append(.minimum(lo)) }
      if let hi = s["maximum"] as? Double { g.append(.maximum(hi)) }
      return DynamicGenerationSchema(type: Double.self, guides: g)
    case "boolean":
      return DynamicGenerationSchema(type: Bool.self)
    default:
      gaps.append("\(path): no/unknown type '\(type ?? "nil")' -> string")
      return DynamicGenerationSchema(type: String.self)
    }
  }
}
