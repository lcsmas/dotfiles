#!/bin/bash
# precommit-lint.sh — PreToolUse hook: lint + typecheck staged files before `git commit`.
#
# - Fires only on `git commit ...` Bash invocations.
# - For each `packages/<pkg>/` with staged .ts/.tsx/.js/.jsx files:
#     - Runs `npx eslint` on staged files (no --fix; would desync the index).
#     - Runs `npx tsc --noEmit` and filters errors to lines touching staged files.
# - Blocks the commit (exit 2 + JSON decision) on any failure, with the offending
#   output included so the model can fix and retry.
# - No-ops silently when: not a git repo, no staged files, no JS/TS, no
#   eslint/tsconfig in the package, or the package isn't `packages/<pkg>/...`.

INPUT=$(cat)
CMD=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{process.stdout.write(JSON.parse(d).tool_input?.command||'')}catch{}})" 2>/dev/null)

if ! [[ "$CMD" =~ (^|[[:space:];&|])git[[:space:]]+commit([[:space:]]|$) ]]; then
  exit 0
fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$REPO" || exit 0

STAGED=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
[ -z "$STAGED" ] && exit 0

TS_FILES=$(echo "$STAGED" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' || true)
[ -z "$TS_FILES" ] && exit 0

declare -A PKG_FILES
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [[ "$f" =~ ^packages/([^/]+)/ ]]; then
    pkg="${BASH_REMATCH[1]}"
    PKG_FILES["$pkg"]+="$f"$'\n'
  fi
done <<< "$TS_FILES"

[ ${#PKG_FILES[@]} -eq 0 ] && exit 0

ERRORS=""

for pkg in "${!PKG_FILES[@]}"; do
  PKG_DIR="packages/$pkg"
  [ ! -d "$PKG_DIR" ] && continue

  HAS_TSCONFIG=0
  HAS_ESLINT=0
  [ -f "$PKG_DIR/tsconfig.json" ] && HAS_TSCONFIG=1
  for cfg in .eslintrc.js .eslintrc.cjs .eslintrc.json eslint.config.js eslint.config.mjs eslint.config.cjs; do
    [ -f "$PKG_DIR/$cfg" ] && HAS_ESLINT=1 && break
  done

  REL_FILES=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    REL_FILES+=("${f#$PKG_DIR/}")
  done <<< "${PKG_FILES[$pkg]}"

  if [ "$HAS_ESLINT" = "1" ] && [ ${#REL_FILES[@]} -gt 0 ]; then
    LINT_OUT=$(cd "$PKG_DIR" && npx --no-install eslint "${REL_FILES[@]}" 2>&1)
    if [ $? -ne 0 ]; then
      ERRORS+="── [$pkg] eslint failed on staged files:"$'\n'"$LINT_OUT"$'\n\n'
    fi
  fi

  if [ "$HAS_TSCONFIG" = "1" ]; then
    TSC_OUT=$(cd "$PKG_DIR" && npx --no-install tsc --noEmit 2>&1)
    if [ $? -ne 0 ]; then
      STAGED_REGEX=""
      for rf in "${REL_FILES[@]}"; do
        [ -z "$rf" ] && continue
        ESC=$(printf '%s' "$rf" | sed 's/[][\\/.+*?()|{}^$]/\\&/g')
        STAGED_REGEX+="${ESC}|"
      done
      STAGED_REGEX="${STAGED_REGEX%|}"
      if [ -n "$STAGED_REGEX" ]; then
        FILTERED=$(echo "$TSC_OUT" | grep -E "($STAGED_REGEX)" || true)
        if [ -n "$FILTERED" ]; then
          ERRORS+="── [$pkg] tsc errors touching staged files:"$'\n'"$FILTERED"$'\n\n'
        fi
      fi
    fi
  fi
done

if [ -n "$ERRORS" ]; then
  REASON="Pre-commit checks failed. Fix the issues, re-stage, then retry the commit."$'\n\n'"$ERRORS"
  node -e "process.stdout.write(JSON.stringify({decision:'block',reason:process.argv[1]}))" "$REASON"
  exit 2
fi

exit 0
