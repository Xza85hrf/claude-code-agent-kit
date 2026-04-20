#!/bin/bash
# check-usage.sh — Check Claude Code usage (session + weekly quotas)
# Usage: bash .claude/scripts/check-usage.sh [--refresh]
#
# Fallback chain: OAuth API → Ollama session scrape → cached/manual.
# Outputs JSON, caches for 30min. Sets budget-mode flag when weekly > 80%.

set -euo pipefail

# === Configuration ===
CACHE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.usage-cache.json"
BUDGET_MODE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.budget-mode"
BUDGET_THRESHOLDS_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.budget-thresholds.env"
WARNING_LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/.usage-warnings.log"
CACHE_TTL=${USAGE_CACHE_TTL:-1800}
CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
BUDGET_THRESHOLD=${USAGE_BUDGET_THRESHOLD:-80}

# === Helper Functions ===

log_warning() {
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[${ts}] $1" >> "$WARNING_LOG"
}

clear_budget_flags() {
    # Drop budget artefacts whenever the cache is known stale. Otherwise a
    # week-old `.budget-mode`=true keeps firing usage-budget-adjust.sh even
    # after reset has passed, and `.budget-thresholds.env` keeps
    # delegation-reminder.sh clamped at the RED thresholds.
    rm -f "$BUDGET_MODE_FILE" "$BUDGET_THRESHOLDS_FILE"
}

check_cache() {
    [[ ! -f "$CACHE_FILE" ]] && return 1
    local now age
    now=$(date +%s)
    age=$((now - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo "$now")))
    [[ "$age" -ge "$CACHE_TTL" ]] && { clear_budget_flags; return 1; }

    # Stored reset timestamps must still be in the future. A cached
    # `weekly_used_pct: 81` paired with `weekly_reset: 2026-04-18`
    # represents last week's utilization — serving it as live data
    # triggers spurious BUDGET MODE [RED] at the top of new sessions.
    local sr wr
    sr=$(jq -r '.session_reset // empty' "$CACHE_FILE" 2>/dev/null)
    wr=$(jq -r '.weekly_reset // empty' "$CACHE_FILE" 2>/dev/null)
    if [[ -n "$sr" ]]; then
        local sr_epoch
        sr_epoch=$(date -d "$sr" +%s 2>/dev/null || echo 0)
        [[ "$sr_epoch" -gt 0 && "$sr_epoch" -le "$now" ]] && { clear_budget_flags; return 1; }
    fi
    if [[ -n "$wr" ]]; then
        local wr_epoch
        wr_epoch=$(date -d "$wr" +%s 2>/dev/null || echo 0)
        [[ "$wr_epoch" -gt 0 && "$wr_epoch" -le "$now" ]] && { clear_budget_flags; return 1; }
    fi

    cat "$CACHE_FILE"
    exit 0
}

try_ollama_scrape() {
    # Scrape usage from ollama.com/settings using __Secure-session cookie
    # Cookie stored in ~/.claude-secrets as OLLAMA_SESSION_COOKIE=<value>
    local cookie=""
    local secrets_file="${HOME}/.claude-secrets"
    if [[ -f "$secrets_file" ]]; then
        cookie=$(grep 'OLLAMA_SESSION_COOKIE=' "$secrets_file" | sed 's/.*OLLAMA_SESSION_COOKIE=//' | tr -d "'\" " || true)
    fi
    cookie="${cookie:-${OLLAMA_SESSION_COOKIE:-}}"
    [[ -z "$cookie" ]] && return 1

    local html
    html=$(curl -s --max-time 10 -b "__Secure-session=$cookie" 'https://ollama.com/settings' 2>/dev/null) || return 1

    # Verify we got the settings page (not a login redirect)
    echo "$html" | grep -q 'Session usage' || { log_warning "Ollama cookie expired or invalid"; return 1; }

    # Parse usage percentages (e.g., "0.1% used", "4.3% used")
    local session_pct weekly_pct session_reset weekly_reset plan premium
    session_pct=$(echo "$html" | grep -A2 'Session usage' | grep -oE '[0-9]+(\.[0-9]+)?% used' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1 || true)
    weekly_pct=$(echo "$html" | grep -A2 'Weekly usage' | grep -oE '[0-9]+(\.[0-9]+)?% used' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1 || true)

    # Parse ISO reset timestamps from data-time attributes
    session_reset=$(echo "$html" | grep -A15 'Session usage' | grep -oE 'data-time="[^"]*"' | head -1 | sed 's/data-time="//;s/"//' || true)
    weekly_reset=$(echo "$html" | grep -A15 'Weekly usage' | grep -oE 'data-time="[^"]*"' | head -1 | sed 's/data-time="//;s/"//' || true)

    # Parse plan (pro/max/free badge near "Cloud Usage")
    plan=$(echo "$html" | grep -A5 'Cloud Usage' | grep -oE '>[a-z]+</span' | head -1 | sed 's/>//;s/<\/span//' || true)

    # Parse premium requests (e.g., "1/20 used")
    premium=$(echo "$html" | grep -A2 'Premium requests' | grep -oE '[0-9]+/[0-9]+ used' | head -1 || true)

    [[ -z "$session_pct" || -z "$weekly_pct" ]] && return 1

    # Round to integer for budget tier calculations (bash can't compare floats)
    session_pct=$(printf '%.0f' "$session_pct" 2>/dev/null || echo "0")
    weekly_pct=$(printf '%.0f' "$weekly_pct" 2>/dev/null || echo "0")

    write_cache "ollama-scrape" "$session_pct" "$session_reset" "$weekly_pct" "$weekly_reset" "Ollama ${plan:-unknown}"
}

try_oauth_api() {
    [[ ! -f "$CREDENTIALS_FILE" ]] && return 1
    local token
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE" 2>/dev/null) || return 1
    [[ -z "$token" ]] && return 1
    local response
    response=$(curl -s --max-time 5 \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage") || return 1
    local session_pct session_reset weekly_pct weekly_reset
    session_pct=$(echo "$response" | jq -r '.five_hour.utilization | if . then round else empty end') || return 1
    session_reset=$(echo "$response" | jq -r '.five_hour.resets_at // empty')
    weekly_pct=$(echo "$response" | jq -r '.seven_day.utilization | if . then round else empty end') || return 1
    weekly_reset=$(echo "$response" | jq -r '.seven_day.resets_at // empty')
    [[ -z "$session_pct" || -z "$weekly_pct" ]] && return 1
    write_cache "oauth" "$session_pct" "$session_reset" "$weekly_pct" "$weekly_reset" ""
}

write_cache() {
    local source="$1" session_pct="$2" session_reset="$3" weekly_pct="$4" weekly_reset="$5" plan="$6"
    # Budget tiers: green (<60%), yellow (60-79%), red (>=80%)
    local budget_mode="false" budget_tier="green"
    local wp_int="${weekly_pct:-0}"
    if [[ "$wp_int" -ge "$BUDGET_THRESHOLD" ]]; then
        budget_mode="true"; budget_tier="red"
    elif [[ "$wp_int" -ge 60 ]]; then
        budget_tier="yellow"
    fi
    local ts json
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    json=$(jq -n \
        --arg ts "$ts" --arg source "$source" \
        --arg sp "$session_pct" --arg sr "$session_reset" \
        --arg wp "$weekly_pct" --arg wr "$weekly_reset" \
        --arg plan "$plan" --argjson bm "$budget_mode" --arg tier "$budget_tier" \
        '{ts:$ts, source:$source, session_used_pct:($sp|tonumber), session_reset:$sr,
          weekly_used_pct:($wp|tonumber), weekly_reset:$wr, plan:$plan, budget_mode:$bm, budget_tier:$tier}')
    echo "$json" > "$CACHE_FILE"
    echo "$budget_mode" > "$BUDGET_MODE_FILE"
    if [[ "$budget_tier" == "red" ]]; then
        printf 'DELEGATION_THRESHOLD=5\nDELEGATION_BLOCK_THRESHOLD=50\n' > "$BUDGET_THRESHOLDS_FILE"
    elif [[ "$budget_tier" == "yellow" ]]; then
        printf 'DELEGATION_THRESHOLD=7\nDELEGATION_BLOCK_THRESHOLD=35\n' > "$BUDGET_THRESHOLDS_FILE"
    elif [[ -f "$BUDGET_THRESHOLDS_FILE" ]]; then
        rm -f "$BUDGET_THRESHOLDS_FILE"
    fi
    echo "$json"
}

# === Main ===
main() {
    [[ "${1:-}" != "--refresh" ]] && check_cache || true

    # Detect Ollama mode — try Ollama scraper first when running as Ollama orchestrator
    local launch_mode="${LAUNCH_MODE:-}"
    [[ -z "$launch_mode" ]] && launch_mode=$(cat "${CLAUDE_PROJECT_DIR:-.}/.claude/.launch-mode" 2>/dev/null || echo "")
    if [[ "$launch_mode" == "ollama" ]]; then
        try_ollama_scrape && exit 0
    fi

    try_oauth_api && exit 0
    if [[ -f "$CACHE_FILE" ]]; then
        # Cache is the last-resort answer, but if the stored resets have
        # already passed the stored percentages are historical — keep
        # printing the JSON for diagnostic value, but clear the
        # downstream budget flags so hooks don't act on dead data.
        local now_ep sr_ep wr_ep
        now_ep=$(date +%s)
        sr_ep=$(date -d "$(jq -r '.session_reset // empty' "$CACHE_FILE" 2>/dev/null)" +%s 2>/dev/null || echo 0)
        wr_ep=$(date -d "$(jq -r '.weekly_reset // empty' "$CACHE_FILE" 2>/dev/null)" +%s 2>/dev/null || echo 0)
        if [[ ( "$sr_ep" -gt 0 && "$sr_ep" -le "$now_ep" ) || ( "$wr_ep" -gt 0 && "$wr_ep" -le "$now_ep" ) ]]; then
            clear_budget_flags
        fi
        log_warning "All sources failed; serving stale cache"
        cat "$CACHE_FILE"
        exit 0
    fi
    log_warning "No data sources available; using manual fallback (50%)"
    write_cache "manual" 50 "" 50 "" "unknown"
}

main "$@"
