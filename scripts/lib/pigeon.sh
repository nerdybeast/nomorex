# Regenerates the Pigeon bridge of every plugin package that has one
# (packages/*/pigeon/messages.dart). Sourced by gen.sh and check-generated.sh.
regenerate_pigeon() {
  local input
  for input in packages/*/pigeon/messages.dart; do
    [[ -f "$input" ]] || continue
    (cd "$(dirname "$(dirname "$input")")" && flutter pub get >/dev/null && dart run pigeon --input pigeon/messages.dart)
  done
}
