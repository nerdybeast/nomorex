/// A cloud AI service the lifter brings their own key for.
///
/// [id] is what the database stores in `ai_import_jobs.provider` and what
/// analytics may carry, so it never changes. [label] is the name lifters know
/// the service by.
enum CloudAiProvider {
  gemini('gemini', 'Gemini'),
  anthropic('anthropic', 'Claude'),
  openai('openai', 'ChatGPT');

  const CloudAiProvider(this.id, this.label);

  final String id;
  final String label;

  static CloudAiProvider? fromId(String? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}
