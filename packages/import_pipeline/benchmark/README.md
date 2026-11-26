# Import benchmark

Runs files through the import pipeline with a real provider and scores the
result against a hand-written answer key. It measures what Stage 5 of #182
asked for, and is the repeatable benchmark #108 wanted.

```bash
cd packages/import_pipeline
ANTHROPIC_API_KEY=... dart run tool/import_bench.dart --provider anthropic benchmark/dense_page.pdf
GEMINI_API_KEY=...    dart run tool/import_bench.dart --provider gemini    benchmark/dense_page.jpg
OPENAI_API_KEY=...    dart run tool/import_bench.dart --provider openai    benchmark/dense_page.pdf
```

The key is read from the environment and never written anywhere. Use your own
key, not the project's.

- `--expected` defaults to the first file's name with `.expected.json`.
- `--model` overrides the provider's default model.
- `--out result.json` saves the normalized result for a closer look.
- `--runs 3` repeats the run, since models vary from run to run.

## Files

| File | What it is |
|---|---|
| `dense_page.jpg`, `dense_page.pdf` | One dense printed program page: 4 days, 32 rows (from the #183 spike). |
| `dense_page.expected.json` | Its answer key. |
| `catalog.json` | The official exercise catalog, as the model sees it. Regenerate it after big catalog changes. |

## Answer keys

```json
{ "days": [ { "title": "Day 1", "exercises": [
  { "name": "Back squat", "sets": 5, "reps": "5", "load": "75%" }
] } ] }
```

Each row is one prescription. `reps` is `"5"` or `"8-10"`. `load` is a
percentage (`"75%"`, `"67-72.5%"`), a weight (`"100kg"`, `"100"` when the file
prints no unit), `"RPE 7"` when only an RPE is given, or `""` for no load.

A row is **exact** when its name (by the app's name rule), sets, reps and load
all match the row in the same place in the same training day. Names are
compared as written in the file, not as matched to the catalog.
