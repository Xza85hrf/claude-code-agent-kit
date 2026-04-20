#!/bin/bash
# engine.sh — Unified execution engine interface
#
# Thin facade over spawn-worker.sh, select-model.sh, model-config.sh,
# worker-orchestrator.sh. Adds: engine-type routing, state-manager
# integration, budget-aware dispatch, and event-bus telemetry.
#
# Usage:
#   source .claude/lib/engine.sh
#   engine_run "auto" "implement user auth" --max-turns 5
#   engine_run "glm-5.1:cloud" "fix bug in parser"
#   engine_run_pipeline "build search feature" --stages "impl,test,review"
#   engine_select "review this code"        # → minimax-m2.7:cloud
#   engine_list                             # Show available engines
#   engine_status                           # Health + budget summary
#
# Engine types: ollama, codex, mcp, claude-subagent
# Auto-routing: task → select-model.sh → engine type → invocation

[[ -n "${_ENGINE_LOADED:-}" ]] && return 0
_ENGINE_LOADED=1

_PROJECT="${CLAUDE_PROJECT_DIR:-.}"
_SCRIPTS="${_PROJECT}/.claude/scripts"
_LIB="${_PROJECT}/.claude/lib"

# Load dependencies (optional — degrade gracefully)
# shellcheck source=state-manager.sh
[[ -f "$_LIB/state-manager.sh" ]] && source "$_LIB/state-manager.sh" 2>/dev/null
# shellcheck source=event-bus.sh
[[ -f "$_LIB/event-bus.sh" ]] && source "$_LIB/event-bus.sh" 2>/dev/null
# shellcheck source=circuit-breaker.sh
[[ -f "$_LIB/circuit-breaker.sh" ]] && source "$_LIB/circuit-breaker.sh" 2>/dev/null

# --- Engine Registry ---
# Each engine: type, invocation method, capabilities, cost tier

declare -A ENGINE_TYPE=()     # model → engine type
declare -A ENGINE_COST=()     # model → cost tier (free/cheap/moderate/expensive)
declare -A ENGINE_CTX=()      # model → context window
declare -A ENGINE_SPEED=()    # model → tokens/sec estimate

_engine_register() {
  local model="$1" type="$2" cost="$3" ctx="$4" speed="${5:-0}"
  ENGINE_TYPE["$model"]="$type"
  ENGINE_COST["$model"]="$cost"
  ENGINE_CTX["$model"]="$ctx"
  ENGINE_SPEED["$model"]="$speed"
}

_engine_init_registry() {
  # Ollama cloud workers (mirrors model-config.sh)
  _engine_register "glm-5.1:cloud"            ollama free  198000  200
  _engine_register "glm-5:cloud"              ollama free  128000  200
  _engine_register "minimax-m2.7:cloud"       ollama free  200000  150
  _engine_register "minimax-m2.5:cloud"       ollama free  196000  150
  _engine_register "deepseek-v3.2:cloud"      ollama free  128000  100
  _engine_register "deepseek-v3.1:671b-cloud" ollama free  128000   80
  _engine_register "gpt-oss:120b-cloud"       ollama free   64000  150
  _engine_register "nemotron-3-super:cloud"   ollama free  512000  120
  _engine_register "nemotron-cascade-2:30b"   ollama free  256000  120
  _engine_register "qwen3-coder-next:cloud"   ollama free  256000  300
  _engine_register "gemma4:31b-cloud"         ollama free  256000  100
  _engine_register "kimi-k2.5:cloud"          ollama free  128000  100
  _engine_register "devstral-2:123b-cloud"    ollama free  128000   80

  # Ollama local workers
  _engine_register "qwen3-coder-next:latest"  ollama free  128000   40
  _engine_register "glm-4.7-flash"            ollama free   32000   60
  _engine_register "qwen3-vl:32b"             ollama free   32000   40
  _engine_register "nemotron-cascade-2:30b"   ollama free  256000   30

  # Groq (free tier, rate-limited)
  _engine_register "groq:gpt-oss-20b"        groq   free   32000 1000
  _engine_register "groq:llama-4-scout"       groq   free   32000  750
  _engine_register "groq:gpt-oss-120b"        groq   free   32000  500
  _engine_register "groq:qwen3-32b"           groq   free   32000  400

  # Codex CLI (via Ollama)
  _engine_register "codex:glm-5.1"            codex  free  198000  200
  _engine_register "codex:gemma4-31b"         codex  free  256000  100
  _engine_register "codex:qwen3-coder-next"   codex  free  256000  300

  # MCP workers (free-models, deepseek, openai)
  _engine_register "mcp:deepseek"             mcp    cheap 128000  100
  _engine_register "mcp:openai"               mcp    moderate 128000 200

  # Claude subagents
  _engine_register "claude:haiku"             claude cheap  200000  300
  _engine_register "claude:sonnet"            claude moderate 200000 200
  _engine_register "claude:opus"              claude expensive 1000000 100
}

_engine_init_registry

# --- Budget Check ---

_engine_budget_tier() {
  # Returns: green (<60%), yellow (60-79%), red (>=80%)
  local budget_file="${_PROJECT}/.budget-thresholds.env"
  if [[ -f "$budget_file" ]]; then
    source "$budget_file" 2>/dev/null
    echo "${BUDGET_TIER:-green}"
  else
    echo "green"
  fi
}

_engine_should_prefer_free() {
  local tier
  tier=$(_engine_budget_tier)
  [[ "$tier" == "yellow" || "$tier" == "red" ]]
}

# --- Core API ---

# engine_select TASK_DESCRIPTION
# Returns: model ID best suited for the task
engine_select() {
  local task="$1"
  local model

  # Use select-model.sh for intelligent routing
  if [[ -x "$_SCRIPTS/select-model.sh" ]]; then
    model=$(bash "$_SCRIPTS/select-model.sh" "$task" 2>/dev/null)
  fi

  # Fallback: default primary worker
  if [[ -z "$model" ]]; then
    # Source model-config if available
    if [[ -f "$_SCRIPTS/model-config.sh" ]]; then
      source "$_SCRIPTS/model-config.sh" 2>/dev/null
      model="${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}"
    else
      model="glm-5.1:cloud"
    fi
  fi

  # Budget override: prefer free models in yellow/red
  if _engine_should_prefer_free; then
    local cost="${ENGINE_COST[$model]:-unknown}"
    if [[ "$cost" == "moderate" || "$cost" == "expensive" ]]; then
      # Downgrade to free equivalent
      model="${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}"
    fi
  fi

  echo "$model"
}

# engine_type MODEL
# Returns: ollama, codex, groq, mcp, claude
engine_type() {
  local model="$1"
  local etype="${ENGINE_TYPE[$model]:-}"

  # Auto-detect from model name if not registered
  if [[ -z "$etype" ]]; then
    case "$model" in
      codex:*)  etype="codex" ;;
      groq:*)   etype="groq" ;;
      mcp:*)    etype="mcp" ;;
      claude:*) etype="claude" ;;
      *)        etype="ollama" ;;  # Default: most models are Ollama
    esac
  fi

  echo "$etype"
}

# engine_run MODEL TASK [OPTIONS...]
# Unified task execution. MODEL can be "auto" for intelligent routing.
# Options pass through to spawn-worker.sh.
# Returns: worker output on stdout, exit code 0/1/124
engine_run() {
  local model="$1" task="$2"
  shift 2
  local opts=("$@")

  # Auto-select model if requested
  if [[ "$model" == "auto" ]]; then
    model=$(engine_select "$task")
  fi

  local etype
  etype=$(engine_type "$model")
  local start_ts
  start_ts=$(date +%s)

  # Publish start event
  if type -t event_publish &>/dev/null; then
    event_publish "worker" "$(jq -nc \
      --arg model "$model" --arg engine "$etype" --arg task "$task" --arg action "start" \
      '{action:$action,model:$model,engine:$engine,task:$task}')"
  fi

  # Circuit breaker check
  if type -t cb_check &>/dev/null; then
    if ! cb_check "$model" 2>/dev/null; then
      echo "ENGINE: Circuit breaker OPEN for $model, using fallback" >&2
      # Try to get a healthy alternative
      if [[ -x "$_SCRIPTS/select-model.sh" ]]; then
        model=$(bash "$_SCRIPTS/select-model.sh" "$task" 2>/dev/null)
        etype=$(engine_type "$model")
      fi
    fi
  fi

  # Dispatch by engine type
  local output="" exit_code=0
  case "$etype" in
    ollama)
      if [[ -x "$_SCRIPTS/spawn-worker.sh" ]]; then
        output=$(bash "$_SCRIPTS/spawn-worker.sh" "$model" "$task" "${opts[@]}" 2>&1)
        exit_code=$?
      else
        # Direct Ollama MCP fallback
        output=$(echo "No spawn-worker.sh available" >&2; return 1)
        exit_code=1
      fi
      ;;

    codex)
      local codex_model="${model#codex:}"
      output=$(codex exec --oss -m "${codex_model}:cloud" "$task" 2>&1)
      exit_code=$?
      ;;

    groq)
      local groq_model="${model#groq:}"
      # Use groq_chat MCP tool — caller must handle MCP invocation
      echo "ENGINE: Groq dispatch requires MCP tool (groq_chat). Model: $groq_model" >&2
      echo "GROQ_MODEL=$groq_model"
      return 0
      ;;

    mcp)
      local mcp_target="${model#mcp:}"
      echo "ENGINE: MCP dispatch to $mcp_target. Use mcp__${mcp_target}__* tools." >&2
      echo "MCP_TARGET=$mcp_target"
      return 0
      ;;

    claude)
      local claude_tier="${model#claude:}"
      echo "ENGINE: Claude subagent dispatch. Use Agent tool with model=$claude_tier." >&2
      echo "CLAUDE_TIER=$claude_tier"
      return 0
      ;;
  esac

  local end_ts elapsed
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))

  # Publish completion event
  if type -t event_publish &>/dev/null; then
    event_publish "worker" "$(jq -nc \
      --arg model "$model" --arg engine "$etype" --arg action "complete" \
      --arg status "$([ $exit_code -eq 0 ] && echo success || echo failure)" \
      --argjson elapsed "$elapsed" --argjson exit_code "$exit_code" \
      '{action:$action,model:$model,engine:$engine,status:$status,elapsed:$elapsed,exit_code:$exit_code}')"
  fi

  # Circuit breaker feedback
  if type -t cb_record &>/dev/null; then
    if [[ $exit_code -eq 0 ]]; then
      cb_record "$model" success 2>/dev/null
    else
      cb_record "$model" failure 2>/dev/null
    fi
  fi

  echo "$output"
  return $exit_code
}

# engine_run_pipeline TASK [OPTIONS...]
# Multi-stage pipeline (implement → test → review → fix).
# Delegates to worker-orchestrator.sh.
engine_run_pipeline() {
  local task="$1"
  shift

  if [[ -x "$_SCRIPTS/worker-orchestrator.sh" ]]; then
    bash "$_SCRIPTS/worker-orchestrator.sh" --task "$task" "$@"
  else
    echo "ERROR: worker-orchestrator.sh not found" >&2
    return 1
  fi
}

# engine_batch TASKS_FILE [OPTIONS...]
# Parallel batch execution via worker-orchestrator.
engine_batch() {
  local tasks_file="$1"
  shift

  if [[ -x "$_SCRIPTS/worker-orchestrator.sh" ]]; then
    bash "$_SCRIPTS/worker-orchestrator.sh" --batch "$tasks_file" "$@"
  else
    # Fallback: sequential via engine_run
    while IFS= read -r task; do
      [[ "$task" =~ ^#|^$ ]] && continue
      engine_run "auto" "$task" "$@"
    done < "$tasks_file"
  fi
}

# engine_list [--available]
# Show registered engines. --available filters to reachable ones.
engine_list() {
  local check_available="${1:-}"

  printf "%-30s %-10s %-10s %-8s %-6s\n" "MODEL" "ENGINE" "COST" "CTX" "T/s"
  printf "%-30s %-10s %-10s %-8s %-6s\n" "-----" "------" "----" "---" "---"

  for model in "${!ENGINE_TYPE[@]}"; do
    local etype="${ENGINE_TYPE[$model]}"
    local cost="${ENGINE_COST[$model]:-?}"
    local ctx="${ENGINE_CTX[$model]:-?}"
    local speed="${ENGINE_SPEED[$model]:-?}"

    if [[ "$check_available" == "--available" ]]; then
      # Quick reachability check for Ollama models
      if [[ "$etype" == "ollama" ]]; then
        local host="${OLLAMA_HOST:-http://localhost:11434}"
        curl -sf "${host}/api/tags" >/dev/null 2>&1 || continue
      fi
    fi

    printf "%-30s %-10s %-10s %-8s %-6s\n" "$model" "$etype" "$cost" "$ctx" "$speed"
  done | sort
}

# engine_status
# Health summary: budget tier, engine availability, recent performance.
engine_status() {
  local tier
  tier=$(_engine_budget_tier)

  echo "Budget tier: $tier"

  # Ollama health
  local host="${OLLAMA_HOST:-http://localhost:11434}"
  if curl -sf "${host}/api/tags" >/dev/null 2>&1; then
    local running
    running=$(curl -sf "${host}/api/ps" 2>/dev/null | jq -r '.models[]?.name' 2>/dev/null | wc -l)
    echo "Ollama: online (${running} models loaded)"
  else
    echo "Ollama: offline"
  fi

  # Recent worker performance
  if type -t state_count &>/dev/null; then
    local total_workers success_workers
    total_workers=$(state_count worker 2>/dev/null || echo "?")
    echo "Worker history: $total_workers entries"
  fi

  # Event bus activity
  if type -t event_peek &>/dev/null; then
    local last_event
    last_event=$(event_peek "worker" 1 2>/dev/null | jq -r '.data.action // empty' 2>/dev/null)
    [[ -n "$last_event" ]] && echo "Last worker event: $last_event"
  fi
}
