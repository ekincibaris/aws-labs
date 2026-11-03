#!/usr/bin/env bash
#
# Run the same checks as CI against every lab in breakfix/, or only the labs you
# pass as arguments: terraform fmt, terraform validate and tflint.
#
#   scripts/check-labs.sh
#   scripts/check-labs.sh breakfix/01-alb-502-bad-gateway
#
# Needs terraform (>= 1.17) and tflint on your PATH. Nothing is deployed and no AWS
# credentials are needed: init runs with -backend=false.

set -uo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tflint_config="$repo_root/.tflint.hcl"

# Share one provider download between all labs instead of fetching it per folder.
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
export TF_IN_AUTOMATION=1
mkdir -p "$TF_PLUGIN_CACHE_DIR"

for tool in terraform tflint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool is not on your PATH" >&2
    exit 2
  fi
done

if [ "$#" -gt 0 ]; then
  labs=("$@")
else
  labs=()
  for dir in "$repo_root"/breakfix/*/; do
    labs+=("${dir%/}")
  done
fi

group_start() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::group::$1"; else printf '\n=== %s\n' "$1"; fi
}

group_end() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::endgroup::"; fi
}

if ! tflint --init --config "$tflint_config" >/dev/null; then
  echo "error: tflint --init failed (set GITHUB_TOKEN if you hit GitHub rate limits)" >&2
  exit 2
fi

failures=0
summary="| Lab | fmt | validate | tflint |\n|---|---|---|---|\n"

for lab in "${labs[@]}"; do
  name="${lab#"$repo_root"/}"
  fmt="pass"
  validate="pass"
  lint="pass"

  group_start "$name"

  if ! terraform -chdir="$lab" fmt -check -recursive -diff; then
    fmt="FAIL"
  fi

  # -lockfile=readonly fails if the committed .terraform.lock.hcl is incomplete.
  if ! init_log="$(terraform -chdir="$lab" init -backend=false -input=false -lockfile=readonly -no-color 2>&1)"; then
    echo "$init_log"
    validate="FAIL (init)"
  elif ! terraform -chdir="$lab" validate -no-color; then
    validate="FAIL"
  fi

  if ! tflint --chdir="$lab" --config="$tflint_config" --format=compact; then
    lint="FAIL"
  fi

  group_end

  if [ "$fmt$validate$lint" != "passpasspass" ]; then
    failures=$((failures + 1))
  fi
  printf '%-45s fmt=%-5s validate=%-12s tflint=%s\n' "$name" "$fmt" "$validate" "$lint"
  summary="$summary| \`$name\` | $fmt | $validate | $lint |\n"
done

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '## Terraform checks\n\n%b\n' "$summary" >>"$GITHUB_STEP_SUMMARY"
fi

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures of ${#labs[@]} lab(s) failed the checks."
  exit 1
fi
echo "All ${#labs[@]} lab(s) passed fmt, validate and tflint."
