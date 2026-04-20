#!/usr/bin/env bash
# knowledge-cache.sh — File-based knowledge cache for AI agent research results
#
# Persistent cache of research results, thinktank decisions, and documentation
# lookups. Agents check cache before doing redundant research.
#
# Usage:
#   # Store knowledge:
#   bash .claude/scripts/knowledge-cache.sh --set "react-server-components" \
#     --content "RSC runs on server..." --tags "react,nextjs" --source "context7"
#
#   # Lookup:
#   bash .claude/scripts/knowledge-cache.sh --get "react-server-components"
#
#   # Search:
#   bash .claude/scripts/knowledge-cache.sh --search "authentication"
#
#   # List all:
#   bash .claude/scripts/knowledge-cache.sh --list
#
#   # Cleanup:
#   bash .claude/scripts/knowledge-cache.sh --expire 30
#
# Commands:
#   --get TOPIC          Lookup by topic name (exact or fuzzy match)
#   --search QUERY       Full-text grep through all knowledge files
#   --set TOPIC          Create/update a topic (requires --content)
#   --list               List all cached topics with age and tags
#   --expire DAYS        Remove entries older than N days (default: 30)
#   --stats              Show cache statistics
#
# Set options:
#   --content TEXT        Content to store (required with --set)
#   --tags TAG1,TAG2      Comma-separated tags
#   --source NAME         Source identifier (thinktank, context7, web, manual)
#   --append              Append to existing topic instead of replacing

set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

# ── Configuration ──
KNOWLEDGE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/.knowledge"
INDEX_FILE="$KNOWLEDGE_DIR/index.json"
TOPICS_DIR="$KNOWLEDGE_DIR/topics"

init_cache() {
  mkdir -p "$TOPICS_DIR"
  if [[ ! -f "$INDEX_FILE" ]]; then
    echo '{}' > "$INDEX_FILE"
  fi
}

sanitize_topic() {
  echo "$1" | tr ' /:' '---' | tr -cd 'a-zA-Z0-9-_'
}

validate_index() {
  if ! jq empty "$INDEX_FILE" 2>/dev/null; then
    echo "Warning: index.json corrupt, rebuilding..." >&2
    rebuild_index
  fi
}

rebuild_index() {
  local new_index='{}'
  for file in "$TOPICS_DIR"/*.md; do
    [[ -e "$file" ]] || continue
    local topic tags source created updated
    topic=$(grep -m1 '^topic: ' "$file" 2>/dev/null | sed 's/^topic: //' || true)
    [[ -z "$topic" ]] && continue
    tags=$(grep -m1 '^tags: ' "$file" 2>/dev/null | sed 's/^tags: //' || echo '')
    source=$(grep -m1 '^source: ' "$file" 2>/dev/null | sed 's/^source: //' || echo '')
    created=$(grep -m1 '^created: ' "$file" 2>/dev/null | sed 's/^created: //' || echo '')
    updated=$(grep -m1 '^updated: ' "$file" 2>/dev/null | sed 's/^updated: //' || echo '')
    new_index=$(echo "$new_index" | jq \
      --arg t "$topic" --arg f "$file" --arg tg "$tags" \
      --arg src "$source" --arg c "$created" --arg u "$updated" \
      '.[$t] = {file:$f, tags:$tg, source:$src, created:$c, updated:$u}')
  done
  echo "$new_index" > "$INDEX_FILE"
}

# ── Commands ──

do_set() {
  local topic="$1" content="$2" tags="$3" source="$4" append="$5"
  local sanitized
  sanitized=$(sanitize_topic "$topic")
  local filepath="$TOPICS_DIR/${sanitized}.md"
  local ts
  ts=$(date -Iseconds)
  local created="$ts"

  if [[ -f "$filepath" ]]; then
    created=$(grep -m1 '^created: ' "$filepath" 2>/dev/null | sed 's/^created: //' || echo "$ts")
    if [[ "$append" == "true" ]]; then
      echo "" >> "$filepath"
      echo "$content" >> "$filepath"
      # Update the updated timestamp in frontmatter
      sed -i "s/^updated: .*/updated: $ts/" "$filepath"
    else
      cat > "$filepath" <<EOF
---
topic: $topic
tags: $tags
source: $source
created: $created
updated: $ts
---

$content
EOF
    fi
  else
    cat > "$filepath" <<EOF
---
topic: $topic
tags: $tags
source: $source
created: $ts
updated: $ts
---

$content
EOF
  fi

  local size
  size=$(wc -c < "$filepath")

  # Update index
  local idx
  idx=$(cat "$INDEX_FILE")
  idx=$(echo "$idx" | jq \
    --arg t "$topic" --arg f "$filepath" --arg tg "$tags" \
    --arg src "$source" --arg c "$created" --arg u "$ts" \
    '.[$t] = {file:$f, tags:$tg, source:$src, created:$c, updated:$u}')
  echo "$idx" > "$INDEX_FILE"

  echo "Cached: $topic ($size bytes)"
}

do_get() {
  local topic="$1"
  validate_index
  local idx
  idx=$(cat "$INDEX_FILE")
  local topic_lower
  topic_lower=$(echo "$topic" | tr '[:upper:]' '[:lower:]')

  # Exact match
  local filepath
  filepath=$(echo "$idx" | jq -r --arg t "$topic" '.[$t].file // empty')

  # Case-insensitive match
  if [[ -z "$filepath" ]]; then
    filepath=$(echo "$idx" | jq -r --arg t "$topic_lower" \
      'to_entries[] | select(.key | ascii_downcase == $t) | .value.file' 2>/dev/null | head -1)
  fi

  # Tag match
  if [[ -z "$filepath" ]]; then
    filepath=$(echo "$idx" | jq -r --arg t "$topic_lower" \
      'to_entries[] | select(.value.tags | ascii_downcase | contains($t)) | .value.file' 2>/dev/null | head -1)
  fi

  if [[ -n "$filepath" && -f "$filepath" ]]; then
    cat "$filepath"
  else
    echo "Not found: $topic" >&2
    exit 1
  fi
}

do_search() {
  local query="$1"
  local results
  results=$(grep -ril "$query" "$TOPICS_DIR/" 2>/dev/null || true)

  if [[ -z "$results" ]]; then
    echo "No results for: $query" >&2
    exit 1
  fi

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    local topic updated
    topic=$(grep -m1 '^topic: ' "$file" 2>/dev/null | sed 's/^topic: //' || basename "$file" .md)
    updated=$(grep -m1 '^updated: ' "$file" 2>/dev/null | sed 's/^updated: //' || echo 'unknown')
    echo "=== $topic (updated: $updated) ==="
    grep -i "$query" "$file" 2>/dev/null | head -2
    echo ""
  done <<< "$results"
}

do_list() {
  validate_index
  local idx
  idx=$(cat "$INDEX_FILE")
  local count
  count=$(echo "$idx" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No cached topics yet."
    return
  fi

  printf "%-35s %-25s %-12s %s\n" "TOPIC" "TAGS" "SOURCE" "UPDATED"
  printf "%-35s %-25s %-12s %s\n" "-----" "----" "------" "-------"

  echo "$idx" | jq -r 'to_entries | sort_by(.value.updated) | reverse | .[] |
    [.key, .value.tags, .value.source, .value.updated] | @tsv' | \
  while IFS=$'\t' read -r topic tags src updated; do
    printf "%-35s %-25s %-12s %s\n" "${topic:0:34}" "${tags:0:24}" "${src:0:11}" "$updated"
  done
}

do_expire() {
  local days="$1"
  local cutoff
  cutoff=$(date -Iseconds -d "$days days ago" 2>/dev/null || date -Iseconds)
  validate_index
  local idx
  idx=$(cat "$INDEX_FILE")
  local removed=0

  local topics_to_remove
  topics_to_remove=$(echo "$idx" | jq -r --arg c "$cutoff" \
    'to_entries[] | select(.value.updated < $c) | .key' 2>/dev/null || true)

  while IFS= read -r topic; do
    [[ -z "$topic" ]] && continue
    local filepath
    filepath=$(echo "$idx" | jq -r --arg t "$topic" '.[$t].file // empty')
    [[ -n "$filepath" && -f "$filepath" ]] && rm "$filepath"
    idx=$(echo "$idx" | jq --arg t "$topic" 'del(.[$t])')
    ((removed++))
  done <<< "$topics_to_remove"

  echo "$idx" > "$INDEX_FILE"
  echo "Removed $removed expired entries (older than $days days)"
}

do_stats() {
  validate_index
  local idx
  idx=$(cat "$INDEX_FILE")
  local total
  total=$(echo "$idx" | jq 'length')

  local total_size=0
  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    local sz
    sz=$(wc -c < "$file")
    total_size=$((total_size + sz))
  done < <(echo "$idx" | jq -r '.[].file')

  echo "Knowledge Cache Statistics"
  echo "========================="
  echo "Total topics:  $total"
  echo "Total size:    $total_size bytes"
  echo ""

  if [[ "$total" -gt 0 ]]; then
    echo "Source distribution:"
    echo "$idx" | jq -r '.[].source' | sort | uniq -c | sort -rn | while read -r cnt src; do
      echo "  $src: $cnt"
    done
    echo ""
    echo "Tag distribution:"
    echo "$idx" | jq -r '.[].tags' | tr ',' '\n' | sed 's/^ //' | sort | uniq -c | sort -rn | head -10 | while read -r cnt tag; do
      [[ -n "$tag" ]] && echo "  $tag: $cnt"
    done
  fi
}

# ── Parse args ──
CMD=""
TOPIC=""
QUERY=""
CONTENT=""
TAGS=""
SOURCE="manual"
APPEND=false
EXPIRE_DAYS=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --get)     CMD="get";     TOPIC="$2"; shift 2 ;;
    --search)  CMD="search";  QUERY="$2"; shift 2 ;;
    --set)     CMD="set";     TOPIC="$2"; shift 2 ;;
    --list)    CMD="list";    shift ;;
    --expire)  CMD="expire";  EXPIRE_DAYS="${2:-30}"; shift 2 ;;
    --stats)   CMD="stats";   shift ;;
    --content) CONTENT="$2";  shift 2 ;;
    --tags)    TAGS="$2";     shift 2 ;;
    --source)  SOURCE="$2";   shift 2 ;;
    --append)  APPEND=true;   shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

init_cache

case "$CMD" in
  get)
    [[ -z "$TOPIC" ]] && { echo "Error: --get requires TOPIC" >&2; exit 1; }
    do_get "$TOPIC" ;;
  search)
    [[ -z "$QUERY" ]] && { echo "Error: --search requires QUERY" >&2; exit 1; }
    do_search "$QUERY" ;;
  set)
    [[ -z "$TOPIC" ]] && { echo "Error: --set requires TOPIC" >&2; exit 1; }
    [[ -z "$CONTENT" ]] && { echo "Error: --set requires --content" >&2; exit 1; }
    do_set "$TOPIC" "$CONTENT" "$TAGS" "$SOURCE" "$APPEND" ;;
  list)    do_list ;;
  expire)  do_expire "$EXPIRE_DAYS" ;;
  stats)   do_stats ;;
  *)
    echo "Usage: knowledge-cache.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  --get TOPIC        Lookup by topic"
    echo "  --search QUERY     Full-text search"
    echo "  --set TOPIC        Store knowledge (requires --content)"
    echo "  --list             List all topics"
    echo "  --expire DAYS      Remove old entries"
    echo "  --stats            Cache statistics"
    exit 1 ;;
esac
