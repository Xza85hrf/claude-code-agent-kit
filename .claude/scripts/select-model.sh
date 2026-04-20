#!/bin/bash
# select-model.sh — Programmatic model router
# Usage: MODEL=$(bash .claude/scripts/select-model.sh "task description")
# Returns: model ID on stdout (e.g., "minimax-m2.7:cloud")
#
# Reads worker-performance.log to learn from past delegations.
# Falls back to keyword-based routing per model-config.sh.

TASK="${1:?Usage: select-model.sh TASK_DESCRIPTION}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model-config.sh" 2>/dev/null
LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/worker-performance.log"
source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
ROUTES_FILE="$SCRIPT_DIR/../config/model-routes.yml"

# --- YAML route matching (if model-routes.yml exists) ---
if [ -f "$ROUTES_FILE" ] && command -v awk &>/dev/null; then
  YAML_MATCH=$(awk -v task="$TASK" '
    /^  - pattern:/ { in_route=1; matched=0; model=""; fallback=""; pipeline=""; script=""; tool="" }
    in_route && /pattern:/ {
      # Extract patterns from the line
      line = $0
      gsub(/.*\[/, "", line)
      gsub(/\].*/, "", line)
      n = split(line, pats, ",")
      for (i=1; i<=n; i++) {
        gsub(/^[[:space:]]*"/, "", pats[i])
        gsub(/"[[:space:]]*$/, "", pats[i])
        # Convert glob to awk pattern
        p = pats[i]
        gsub(/\*/, ".*", p)
        if (tolower(task) ~ tolower(p)) { matched=1; break }
      }
    }
    in_route && /^    model:/ { gsub(/^    model:[[:space:]]*/, ""); model=$0 }
    in_route && /^    fallback:/ { gsub(/^    fallback:[[:space:]]*/, ""); fallback=$0 }
    in_route && /^    pipeline:/ { gsub(/^    pipeline:[[:space:]]*/, ""); pipeline=$0 }
    in_route && /^    script:/ { gsub(/^    script:[[:space:]]*/, ""); script=$0 }
    in_route && /^    tool:/ { gsub(/^    tool:[[:space:]]*/, ""); tool=$0 }
    in_route && /^  - / && !/pattern:/ { in_route=0 }
    in_route && /^[^ ]/ && !/^  / { in_route=0 }
    matched && (model != "" || pipeline != "") {
      if (pipeline != "") print "pipeline:" pipeline
      else print model
      exit
    }
  ' "$ROUTES_FILE" 2>/dev/null)

  if [ -n "$YAML_MATCH" ]; then
    case "$YAML_MATCH" in
      pipeline:multi-model-audit)   echo "multi-model-audit"; exit 0 ;;
      pipeline:image-generation)    echo "gemini-mcp"; exit 0 ;;
      pipeline:video-generation)    echo "gemini-mcp"; exit 0 ;;
      *)                            echo "$YAML_MATCH"; exit 0 ;;
    esac
  fi
fi

# --- Keyword-based classification (fallback) ---
# Priority: MCP/script-routed patterns first (they exit early), then Ollama-routed.
# Bash case uses first-match, so order matters.
TASK_TYPE="unknown"
case "$TASK" in
  # ── MCP/script-routed (highest priority) ──
  *[Cc]onsensus*|*[Mm]ulti.model*[Aa]udit*|*[Mm]ulti.model*[Rr]eview*)  TASK_TYPE="MultiModelAudit" ;;
  *[Ff]rontend*|*[Cc][Ss][Ss]*|*[Hh][Tt][Mm][Ll]*|*[Ll]ayout*|*[Ss]tyl*|*[Ll]anding*|*[Pp]age*|*[Dd]esign*|*[Uu]ser*[Ii]nterface*|*" UI "*|*" ui "*) TASK_TYPE="Frontend" ;;  # Opus-first, workers gen code
  *[Ii]mage*gen*|*[Gg]enerate*[Ii]mage*|*[Mm]ockup*|*[Ii]con*|*[Bb]anner*|*[Ll]ogo*) TASK_TYPE="ImageGen" ;;
  *[Vv]ideo*|*[Dd]emo*vid*)              TASK_TYPE="VideoGen" ;;
  # ── Ollama-routed (standard patterns) ──
  *[Tt]est*|*[Ss]pec*)                    TASK_TYPE="GenerateTestFile" ;;
  *[Rr]eview*|*[Aa]udit*)                 TASK_TYPE="ReviewCode" ;;
  *[Rr]efactor*)                           TASK_TYPE="RefactorFunction" ;;
  *[Ff]ix*|*[Dd]ebug*|*[Bb]ug*)           TASK_TYPE="FixBug" ;;
  *[Cc]omponent*|*[Ww]idget*)             TASK_TYPE="GenerateComponent" ;;
  *[Ss]chema*|*[Tt]able*|*[Mm]igrat*)     TASK_TYPE="GenerateSchema" ;;
  *[Ss]ervice*|*[Mm]iddleware*)            TASK_TYPE="GenerateService" ;;
  *[Tt]ype*|*[Ii]nterface*)               TASK_TYPE="GenerateTypes" ;;
  *[Rr]oute*|*[Ee]ndpoint*|*[Aa]pi*)      TASK_TYPE="ScaffoldRoute" ;;
  *[Dd]oc*|*[Cc]omment*|*[Rr]eadme*)      TASK_TYPE="WriteDocstring" ;;
  *[Bb]oilerplate*|*CRUD*|*[Ss]caffold*|*[Ss]keleton*|*[Ss]tub*) TASK_TYPE="Boilerplate" ;;
  *[Ll]ong*context*|*[Ll]arge*file*|*[Ss]ummariz*|*100[kK]*) TASK_TYPE="LongContext" ;;
  *[Vv]ision*|*[Ss]creenshot*|*[Oo]CR*)   TASK_TYPE="Vision" ;;
  *[Ii]mage*|*[Hh]ero*image*|*[Hh]ero*banner*) TASK_TYPE="ImageGen" ;;
  *[Rr]eason*|*[Aa]nalyz*|*[Ee]xplain*why*|*[Rr]oot*cause*) TASK_TYPE="Reasoning" ;;
  *[Pp]rogrammatic*[Tt]ool*|*[Pp][Tt][Cc]*|*[Aa]gent*orchestr*|*allowed.caller*) TASK_TYPE="Reasoning" ;;
  *[Aa]gent*|*[Aa]utonomous*|*[Mm]ulti.step*) TASK_TYPE="Agentic" ;;
esac
# Note: Boilerplate routes to glm-5 (default) — it's a better coder than glm-4.7

# --- Default model assignments (from model-config.sh MODEL_* vars) ---
# Hardcoded fallbacks must mirror model-config.sh and match the current kit
# state — if you update one, update the other. If model-config.sh fails to
# source, these defaults become authoritative, so stale values here become
# silent landmines.
DEFAULT_MODEL="${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}"
case "$TASK_TYPE" in
  MultiModelAudit)    DEFAULT_MODEL="multi-model-audit" ;;
  ReviewCode)         DEFAULT_MODEL="${MODEL_WORKER_REVIEW:-minimax-m2.7:cloud}" ;;
  RefactorFunction)   DEFAULT_MODEL="${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}" ;;
  FixBug)             DEFAULT_MODEL="${MODEL_WORKER_REASONING:-deepseek-v3.2:cloud}" ;;
  WriteDocstring)     DEFAULT_MODEL="${MODEL_WORKER_FAST:-qwen3-coder-next:cloud}" ;;
  GenerateSchema)     DEFAULT_MODEL="${MODEL_WORKER_FAST:-qwen3-coder-next:cloud}" ;;
  LongContext)        DEFAULT_MODEL="${MODEL_WORKER_LONGCTX:-nemotron-3-super:cloud}" ;;
  Vision)             DEFAULT_MODEL="${MODEL_WORKER_VISION:-gemma4:31b-cloud}" ;;
  Frontend)           DEFAULT_MODEL="${MODEL_FRONTEND_WORKER:-glm-5.1:cloud}" ;;
  ImageGen)           DEFAULT_MODEL="gemini-mcp" ;;
  VideoGen)           DEFAULT_MODEL="gemini-mcp" ;;
  Reasoning)          DEFAULT_MODEL="${MODEL_WORKER_REASONING:-deepseek-v3.2:cloud}" ;;
  Agentic)            DEFAULT_MODEL="${MODEL_WORKER_AGENTIC:-nemotron-3-super:cloud}" ;;
esac

# --- Special routing (not Ollama models — use scripts/MCP tools directly) ---
if [ "$DEFAULT_MODEL" = "gemini-mcp" ]; then
  echo "gemini-mcp"
  exit 0
fi
if [ "$DEFAULT_MODEL" = "multi-model-audit" ]; then
  echo "multi-model-audit"
  exit 0
fi

# --- Data-driven routing: use model profiles if enough data ---
if [ -f "$LOG_FILE" ] && command -v jq &>/dev/null; then
  # Get the best model for this task type based on affinity + reliability
  PROFILE_PICK=$(jq -s --arg task "$TASK_TYPE" '
    [.[] | select(.model != "gate" and .model != null)]
    | group_by(.model)
    | map({
        model: .[0].model,
        total: length,
        task_success: ([.[] | select(.task == $task and .status == "success")] | length),
        task_total: ([.[] | select(.task == $task)] | length),
        overall_reliability: (([.[] | select(.status == "success")] | length) * 100 / (length | if . == 0 then 1 else . end))
      })
    | [.[] | select(.task_total >= 2)]
    | sort_by(-((.task_success * 100 / (.task_total | if . == 0 then 1 else . end)) + .overall_reliability))
    | .[0].model // empty
  ' "$LOG_FILE" 2>/dev/null)

  if [ -n "$PROFILE_PICK" ] && [ "$PROFILE_PICK" != "null" ]; then
    DEFAULT_MODEL="$PROFILE_PICK"
  fi
fi

# --- Verify model is available ---
AVAILABLE=$(curl -s --max-time 2 "$OLLAMA_HOST/api/tags" 2>/dev/null)
if echo "$AVAILABLE" | jq -e --arg m "$DEFAULT_MODEL" '.models[]? | select(.name==$m)' >/dev/null 2>&1; then
  echo "$DEFAULT_MODEL"
else
  for FALLBACK in "${MODEL_FALLBACK_WORKER:-minimax-m2.5:cloud}" "${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}" "${MODEL_WORKER_FAST:-qwen3-coder-next:cloud}"; do
    if echo "$AVAILABLE" | jq -e --arg m "$FALLBACK" '.models[]? | select(.name==$m)' >/dev/null 2>&1; then
      echo "$FALLBACK"
      exit 0
    fi
  done
  echo "$DEFAULT_MODEL"
fi
