import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// JSON Schema, as Genkit and schemantic emit it, to a
  /// `DynamicGenerationSchema` (from the #183 spike).
  ///
  /// Translated: objects with required and optional fields, arrays with
  /// min/max items, string enums, integers and numbers with min/max,
  /// booleans, and `$defs`/`$ref`. Each `$defs` entry keeps its exact name,
  /// or Apple fails with `undefinedReferences`.
  ///
  /// Dropped, and listed in [gaps]: `maxLength`, `pattern`, `format` and the
  /// like (put them in the prompt and check them in Dart), and nullability
  /// (a nullable field becomes optional).
  ///
  /// Not translatable, setting [unsupported]: free-form maps
  /// (`additionalProperties` with no `properties`). The Dart side then puts
  /// the schema in the prompt instead.
  @available(iOS 26.0, macOS 26.0, *)
  final class SchemaConverter {
    private(set) var gaps: [String] = []
    private(set) var unsupported = false
    private var dependencies: [DynamicGenerationSchema] = []
    private var counter = 0
    private let handled: Set<String> = [
      "type", "properties", "required", "items", "enum", "description", "minItems", "maxItems", "$defs", "$ref",
      "anyOf", "title", "additionalProperties", "minimum", "maximum", "$schema",
    ]

    func convertRoot(_ json: [String: Any]) throws -> GenerationSchema {
      if let defs = json["$defs"] as? [String: Any] {
        for (name, def) in defs.sorted(by: { $0.key < $1.key }) {
          if let d = def as? [String: Any] {
            dependencies.append(convert(d, name: name, exactName: true, path: "$defs." + name))
          }
        }
      }
      let root = convert(json, name: "Root")
      return try GenerationSchema(root: root, dependencies: dependencies)
    }

    private func nextName(_ base: String) -> String {
      counter += 1
      return "\(base)_\(counter)"
    }

    private func convert(
      _ s: [String: Any], name: String, exactName: Bool = false, path: String = "$"
    ) -> DynamicGenerationSchema {
      for key in s.keys.sorted() where !handled.contains(key) { gaps.append("\(path): dropped '\(key)'") }
      if let ref = s["$ref"] as? String {
        return DynamicGenerationSchema(referenceTo: String(ref.split(separator: "/").last ?? ""))
      }
      if let any = s["anyOf"] as? [[String: Any]] {
        let nonNull = any.filter { ($0["type"] as? String) != "null" }
        if nonNull.count == 1 {
          gaps.append("\(path): nullable, made optional")
          return convert(nonNull[0], name: name, path: path)
        }
        return DynamicGenerationSchema(
          name: nextName(name), anyOf: nonNull.map { convert($0, name: name, path: path + "|") })
      }
      var type = s["type"] as? String
      if let types = s["type"] as? [String] {
        let nonNull = types.filter { $0 != "null" }
        if nonNull.count != types.count { gaps.append("\(path): nullable, made optional") }
        type = nonNull.first
      }
      let description = s["description"] as? String
      switch type {
      case "object":
        let properties = s["properties"] as? [String: Any] ?? [:]
        let required = Set(s["required"] as? [String] ?? [])
        if properties.isEmpty, s["additionalProperties"] != nil {
          unsupported = true
          gaps.append("\(path): free-form map")
        }
        let converted = properties.keys.sorted().map { key -> DynamicGenerationSchema.Property in
          let p = properties[key] as? [String: Any] ?? [:]
          return .init(
            name: key, description: p["description"] as? String,
            schema: convert(p, name: name + "_" + key, path: path + "." + key),
            isOptional: !required.contains(key))
        }
        return DynamicGenerationSchema(
          name: exactName ? name : nextName(name), description: description, properties: converted)
      case "array":
        let items = s["items"] as? [String: Any] ?? ["type": "string"]
        return DynamicGenerationSchema(
          arrayOf: convert(items, name: name + "_item", path: path + "[]"),
          minimumElements: s["minItems"] as? Int, maximumElements: s["maxItems"] as? Int)
      case "string":
        if let values = s["enum"] as? [String] {
          return DynamicGenerationSchema(name: nextName(name), description: description, anyOf: values)
        }
        return DynamicGenerationSchema(type: String.self)
      case "integer":
        var guides: [GenerationGuide<Int>] = []
        if let lo = (s["minimum"] as? NSNumber)?.intValue { guides.append(.minimum(lo)) }
        if let hi = (s["maximum"] as? NSNumber)?.intValue { guides.append(.maximum(hi)) }
        return DynamicGenerationSchema(type: Int.self, guides: guides)
      case "number":
        var guides: [GenerationGuide<Double>] = []
        if let lo = (s["minimum"] as? NSNumber)?.doubleValue { guides.append(.minimum(lo)) }
        if let hi = (s["maximum"] as? NSNumber)?.doubleValue { guides.append(.maximum(hi)) }
        return DynamicGenerationSchema(type: Double.self, guides: guides)
      case "boolean":
        return DynamicGenerationSchema(type: Bool.self)
      default:
        gaps.append("\(path): no type, read as a string")
        return DynamicGenerationSchema(type: String.self)
      }
    }
  }
#endif
