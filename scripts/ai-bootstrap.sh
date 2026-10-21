#!/usr/bin/env bash
# ai-bootstrap.sh — set up (or check) one machine for the 108 AI development workflow.
#
#   scripts/ai-bootstrap.sh            install what is missing, then run the read-only test
#   scripts/ai-bootstrap.sh --check    change nothing; report what is missing or drifted
#   scripts/ai-bootstrap.sh --skip-verify   install, but skip the read-only test (costs a few model calls)
#
# Every pin comes from AI_AGENT_ROLES.lock beside this repo's root; nothing here is a second copy.
# Safe to re-run. Never overwrites a file that differs from the pin without saying so first.
set -euo pipefail

MODE=install; VERIFY=1
for a in "$@"; do
  case $a in
    --check) MODE=check ;;
    --skip-verify) VERIFY=0 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

DOCS=$(cd "$(dirname "$0")/.." && pwd)
ECO=$(dirname "$DOCS")                     # ~/108-ecosystem: the docs repo's parent
LOCK=$DOCS/AI_AGENT_ROLES.lock
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
FAIL=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  MISS  %s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  note  %s\n' "$*"; }

for t in git curl shasum claude; do
  command -v $t >/dev/null || { echo "required tool not found: $t (install it, then re-run)" >&2; exit 1; }
done

# lock value: section key  ->  value (text after '=', comment stripped)
lockval() { awk -v s="[$1]" -v k="$2" '$0==s{f=1;next} /^\[/{f=0} f && $1==k {sub(/^[^=]*=[ ]*/,""); sub(/[ ]+#.*/,""); print; exit}' "$LOCK"; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
raw() { curl -fsSL "https://raw.githubusercontent.com/$1/$2/$3"; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# install <dest> <expected-sha256> <staged-file>
place() {
  local dest=$1 want=$2 staged=$3
  if [ "$(sha "$staged")" != "$want" ]; then bad "$dest: built file does not match the lock ($(sha "$staged"))"; return; fi
  if [ -f "$dest" ] && [ "$(sha "$dest")" = "$want" ]; then ok "$dest"; return; fi
  if [ "$MODE" = check ]; then bad "$dest ($([ -f "$dest" ] && echo differs || echo absent))"; return; fi
  [ -f "$dest" ] && { cp "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"; note "$dest differed; previous copy kept as .bak.*"; }
  mkdir -p "$(dirname "$dest")"; cp "$staged" "$dest"; ok "$dest (installed)"
}

echo "== agency-agents (reviewer roles)"
REPO=$(lockval agency-agents source | sed 's#https://github.com/##')
REV=$(lockval agency-agents revision)
TOOLS=$(lockval agency-agents tools)
while read -r path blob want; do
  slug=$(basename "$path" .md)
  raw "$REPO" "$REV" "$path" > "$TMP/$slug.up" || { bad "$slug: download failed"; continue; }
  [ "$(git hash-object "$TMP/$slug.up")" = "$blob" ] || { bad "$slug: upstream blob mismatch"; continue; }
  desc=$(awk 'NR>1 && /^---$/{exit} /^description: /{print; exit}' "$TMP/$slug.up")
  { printf -- '---\nname: %s\n%s\ntools: %s\n---\n' "$slug" "$desc" "$TOOLS"
    awk 'c>=2{print} /^---$/{c++}' "$TMP/$slug.up"; } > "$TMP/$slug.md"
  place "$CLAUDE_DIR/agents/$slug.md" "$want" "$TMP/$slug.md"
done < <(awk '/^\[agency-agents\]/{f=1;next} /^\[/{f=0} f && $1 ~ /\.md$/ {print $1, $2, $3}' "$LOCK")

echo "== karpathy-guidelines (skill)"
KREPO=$(lockval karpathy-guidelines source | sed 's#https://github.com/##')
raw "$KREPO" "$(lockval karpathy-guidelines revision)" "$(lockval karpathy-guidelines path)" > "$TMP/SKILL.md"
if [ "$(git hash-object "$TMP/SKILL.md")" = "$(lockval karpathy-guidelines upstream_blob)" ]; then
  place "$CLAUDE_DIR/skills/karpathy-guidelines/SKILL.md" "$(lockval karpathy-guidelines installed_sha256)" "$TMP/SKILL.md"
else bad "karpathy-guidelines: upstream blob mismatch"; fi

echo "== context-mode (plugin)"
CM_WANT=$(lockval context-mode version)
CM_HAVE=$(claude plugin list 2>/dev/null | awk '/context-mode@context-mode/{f=1} f && /Version:/{print $2; exit}')
if [ -n "$CM_HAVE" ]; then
  [ "$CM_HAVE" = "$CM_WANT" ] && ok "context-mode $CM_HAVE" || note "context-mode $CM_HAVE installed; lock records $CM_WANT (update the lock by PR if newer is intended)"
elif [ "$MODE" = check ]; then bad "context-mode plugin not installed"
else
  claude plugin marketplace add mksglu/context-mode >/dev/null && claude plugin install context-mode@context-mode >/dev/null \
    && ok "context-mode (installed; restart Claude Code to load it)" || bad "context-mode install failed; run: claude plugin install context-mode@context-mode"
fi
command -v rtk >/dev/null && ok "rtk $(rtk --version 2>/dev/null | awk '{print $2}')" || note "rtk not installed (optional token saver: brew install rtk)"

echo "== ecosystem root CLAUDE.md"
SRC=$DOCS/ECOSYSTEM_ROOT_CLAUDE.md
for f in CLAUDE.md AGENTS.md; do
  dest=$ECO/$f
  if [ -L "$dest" ] && [ "$(cd "$ECO" && realpath "$f")" = "$(realpath "$SRC")" ]; then ok "$dest -> docs copy"
  elif [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    [ "$MODE" = check ] && bad "$dest absent" || { ln -s "$(basename "$DOCS")/ECOSYSTEM_ROOT_CLAUDE.md" "$dest"; ok "$dest (linked)"; }
  elif [ -L "$dest" ] && [ "$f" = AGENTS.md ] && [ "$(readlink "$dest")" = CLAUDE.md ]; then ok "$dest -> CLAUDE.md"
  elif cmp -s "$dest" "$SRC"; then note "$dest is a copy identical to the docs version; replace it with a symlink to stay in sync"
  else note "$dest differs from $SRC — left untouched; diff them and bring local facts into the docs repo by PR"; fi
done

echo "== memory-search"
if command -v memq >/dev/null; then ok "memq $(memq --version 2>/dev/null || true)"
else note "not installed — repo-scoped memory-search is not released yet; read docs/AI_CONTEXT_INDEX.md by hand"; fi

if [ "$MODE" = install ] && [ "$VERIFY" = 1 ] && [ "$FAIL" = 0 ]; then
  echo "== read-only test (AI_REVIEW_PROTOCOL.md#enforcement-check)"
  allowed=",${TOOLS// /},"
  while read -r path _; do
    slug=$(basename "$path" .md); probe="$TMP/probe-$slug"
    (cd "$TMP" && claude -p "Tool test, no other work: try once each to Write the file $probe, and to run the shell command 'touch $probe'. Then reply DONE." \
       --agent "$slug" --model haiku --output-format stream-json --verbose </dev/null 2>/dev/null) > "$TMP/$slug.jsonl" || true
    tools=$(grep -m1 '"subtype":"init"' "$TMP/$slug.jsonl" | sed -E 's/.*"tools":\[([^]]*)\].*/\1/' | tr -d '" ')
    extra=""; IFS=, read -ra arr <<< "$tools"; for t in "${arr[@]}"; do [[ $allowed == *",$t,"* ]] || extra+="$t "; done
    if [ -z "$tools" ]; then bad "$slug: no init record (is Claude Code logged in?)"
    elif [ -n "$extra" ] || [ -e "$probe" ]; then bad "$slug: NOT read-only (extra tools: ${extra:-none}; probe written: $([ -e "$probe" ] && echo yes || echo no))"
    else ok "$slug tools=[$tools]"; fi
  done < <(awk '/^\[agency-agents\]/{f=1;next} /^\[/{f=0} f && $1 ~ /\.md$/ {print $1}' "$LOCK")
  have=$(claude --version | awk '{print $1}'); want=$(lockval enforcement claude_code_version)
  [ "$have" = "$want" ] || note "Claude Code $have differs from lock $want: if the test passed, update [enforcement] in the lock by PR"
fi

echo
if [ "$FAIL" = 0 ]; then echo "ready — read AI_DEVELOPMENT_WORKFLOW.md before your next feature or fix"; else echo "$FAIL problem(s) above"; exit 1; fi
