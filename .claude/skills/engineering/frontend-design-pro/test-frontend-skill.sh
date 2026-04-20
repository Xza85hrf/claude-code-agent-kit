#!/usr/bin/env bash
# test-frontend-skill.sh — Test the frontend-design-pro skill across model tiers
#
# Usage:
#   bash test-frontend-skill.sh gemini              # Gemini Pro via API
#   bash test-frontend-skill.sh gemini flash        # Gemini Flash via API
#   bash test-frontend-skill.sh ollama MODEL        # Ollama cloud model via API
#   bash test-frontend-skill.sh claude              # Claude via claude -p
#   bash test-frontend-skill.sh all                 # Run all tiers
#
# Environment:
#   GEMINI_API_KEY  — required for gemini tier
#   OLLAMA_API_KEY  — required for ollama cloud tier
#   OLLAMA_HOST     — Ollama endpoint (default: http://host.docker.internal:11434)
#
# Output: test-outputs/{tier}-{model}-{timestamp}.html

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Source model config for role-based model vars
source "${SCRIPT_DIR}/../../../scripts/model-config.sh" 2>/dev/null || true
OUTPUT_DIR="$SCRIPT_DIR/test-outputs"
BRIEF_FILE="$SCRIPT_DIR/test-brief.md"
SKILL_FILE="$SCRIPT_DIR/SKILL.md"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$OUTPUT_DIR"

# Extract the prompt template from the test brief (everything after "---" at the end)
get_prompt() {
    local skill_context
    # Read phases 1-4 from SKILL.md (skip frontmatter, stop before Phase 5)
    skill_context=$(sed -n '/^# PRO Frontend/,/^## Phase 5/p' "$SKILL_FILE" | head -n -1)

    cat <<'PROMPT_EOF'
You are a premium frontend designer. Generate a complete, self-contained HTML file for a SaaS landing page for "CodeLens AI" — an AI-powered code review tool.

Requirements:
- Dark theme, NOT white background
- Do NOT use Inter, Roboto, or Arial fonts — choose expressive, premium font pairings from Google Fonts
- Do NOT use generic purple gradients — create a unique, cohesive color palette
- Hero section: "Ship Better Code, Faster" headline with cinematic reveal animation
- 3 feature cards in a bento grid: "Instant Reviews", "Security Scanning", "Team Insights"
- Stats strip: "50,000+ repos", "2M+ reviews", "99.9% uptime"
- CTA section with "Start free trial" button
- Simple footer
- At least one premium animation (stagger reveal, glassmorphism, gradient glow, parallax)
- Mobile responsive
- Self-contained: inline CSS + JS, only external dependency is Google Fonts
- Use CSS custom properties for all design tokens
- GPU-safe animations only (transform, opacity)

Output ONLY the complete HTML file, no explanations.
PROMPT_EOF
}

# Extract HTML from model response (strip markdown fences if present)
extract_html() {
    local input="$1"
    # Remove ```html ... ``` fences
    echo "$input" | sed -n '/^```html/,/^```$/p' | sed '1d;$d' | head -1 > /dev/null 2>&1
    local fenced
    fenced=$(echo "$input" | sed -n '/^```html/,/^```$/p' | sed '1d;$d')
    if [[ -n "$fenced" ]]; then
        echo "$fenced"
    else
        # Try ```...``` without html tag
        fenced=$(echo "$input" | sed -n '/^```/,/^```$/p' | sed '1d;$d')
        if [[ -n "$fenced" ]]; then
            echo "$fenced"
        else
            # Return as-is (might already be raw HTML)
            echo "$input"
        fi
    fi
}

# === GEMINI TIER ===
run_gemini() {
    local model="${1:-pro}"
    local api_model

    if [[ "$model" == "pro" ]]; then
        api_model="gemini-3.1-pro-preview"
    elif [[ "$model" == "flash" ]]; then
        api_model="gemini-3-flash-preview"
    else
        api_model="$model"
    fi

    if [[ -z "${GEMINI_API_KEY:-}" ]]; then
        echo "ERROR: GEMINI_API_KEY not set" >&2
        return 1
    fi

    local prompt
    prompt=$(get_prompt)
    local outfile="$OUTPUT_DIR/gemini-${model}-${TIMESTAMP}.html"

    echo ">>> Generating with Gemini ($api_model)..."

    local response
    response=$(curl -s --max-time 120 \
        "https://generativelanguage.googleapis.com/v1beta/models/${api_model}:generateContent?key=${GEMINI_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "$(jq -n --arg prompt "$prompt" '{
            contents: [{parts: [{text: $prompt}]}],
            generationConfig: {temperature: 0.8, maxOutputTokens: 16000}
        }')")

    local text
    text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)

    if [[ -z "$text" ]]; then
        echo "ERROR: Empty response from Gemini" >&2
        echo "$response" | jq '.error // .' 2>/dev/null >&2
        return 1
    fi

    extract_html "$text" > "$outfile"
    local size
    size=$(wc -c < "$outfile")
    echo ">>> Saved: $outfile ($size bytes)"
}

# === OLLAMA TIER ===
run_ollama() {
    local model="${1:-${MODEL_WORKER_REVIEW:-minimax-m2.7:cloud}}"
    local host="${OLLAMA_HOST:-http://host.docker.internal:11434}"

    local prompt
    prompt=$(get_prompt)
    local safe_model
    safe_model=$(echo "$model" | tr ':/' '-')
    local outfile="$OUTPUT_DIR/ollama-${safe_model}-${TIMESTAMP}.html"

    echo ">>> Generating with Ollama ($model)..."

    local response
    response=$(curl -s --max-time 300 \
        "${host}/api/chat" \
        -H 'Content-Type: application/json' \
        ${OLLAMA_API_KEY:+-H "Authorization: Bearer $OLLAMA_API_KEY"} \
        -d "$(jq -n --arg model "$model" --arg prompt "$prompt" '{
            model: $model,
            messages: [{role: "user", content: $prompt}],
            stream: false,
            options: {temperature: 0.8, num_predict: 16000}
        }')")

    local text
    text=$(echo "$response" | jq -r '.message.content // empty' 2>/dev/null)

    if [[ -z "$text" ]]; then
        echo "ERROR: Empty response from Ollama ($model)" >&2
        echo "$response" | head -5 >&2
        return 1
    fi

    extract_html "$text" > "$outfile"
    local size
    size=$(wc -c < "$outfile")
    echo ">>> Saved: $outfile ($size bytes)"
}

# === CLAUDE TIER ===
run_claude() {
    local prompt
    prompt=$(get_prompt)
    local outfile="$OUTPUT_DIR/claude-opus-${TIMESTAMP}.html"

    echo ">>> Generating with Claude (via claude -p)..."

    if ! command -v claude &>/dev/null; then
        echo "ERROR: claude CLI not found" >&2
        return 1
    fi

    local text
    text=$(echo "$prompt" | claude -p --output-format text 2>/dev/null)

    if [[ -z "$text" ]]; then
        echo "ERROR: Empty response from Claude" >&2
        return 1
    fi

    extract_html "$text" > "$outfile"
    local size
    size=$(wc -c < "$outfile")
    echo ">>> Saved: $outfile ($size bytes)"
}

# === COMPARE ===
compare_outputs() {
    echo ""
    echo "=== Test Results ==="
    echo ""
    printf "%-45s %8s %5s %5s %5s\n" "File" "Size" "Fonts" "Anim" "Vars"
    printf "%-45s %8s %5s %5s %5s\n" "----" "----" "-----" "----" "----"

    for f in "$OUTPUT_DIR"/*-"${TIMESTAMP}".html; do
        [[ -f "$f" ]] || continue
        local name size fonts anims vars
        name=$(basename "$f")
        size=$(wc -c < "$f")
        # Count Google Fonts references
        fonts=$(grep -c "fonts.googleapis.com" "$f" 2>/dev/null || echo 0)
        # Count @keyframes (animation definitions)
        anims=$(grep -c "@keyframes" "$f" 2>/dev/null || echo 0)
        # Count CSS custom properties
        vars=$(grep -c "\-\-[a-z]" "$f" 2>/dev/null || echo 0)
        printf "%-45s %7sB %5s %5s %5s\n" "$name" "$size" "$fonts" "$anims" "$vars"
    done

    echo ""
    echo "Fonts = Google Fonts imports, Anim = @keyframes defs, Vars = CSS custom properties"
    echo "Open files in browser to visually compare."
}

# === MAIN ===
case "${1:-help}" in
    gemini)
        run_gemini "${2:-pro}"
        compare_outputs
        ;;
    ollama)
        run_ollama "${2:-minimax-m2.7:cloud}"
        compare_outputs
        ;;
    claude)
        run_claude
        compare_outputs
        ;;
    all)
        echo "=== Running all tiers ==="
        run_gemini "pro" || echo "WARN: Gemini pro failed"
        run_gemini "flash" || echo "WARN: Gemini flash failed"
        run_ollama "minimax-m2.7:cloud" || echo "WARN: Ollama minimax failed"
        run_ollama "glm-5.1:cloud" || echo "WARN: Ollama glm-5.1 failed"
        run_claude || echo "WARN: Claude failed"
        compare_outputs
        ;;
    compare)
        TIMESTAMP="*"  # Match all timestamps
        compare_outputs
        ;;
    help|*)
        echo "Usage: bash $0 {gemini|ollama|claude|all|compare} [model]"
        echo ""
        echo "Tiers:"
        echo "  gemini [pro|flash]           — Gemini API (needs GEMINI_API_KEY)"
        echo "  ollama [model]               — Ollama cloud (needs OLLAMA_API_KEY)"
        echo "  claude                       — Claude via claude -p"
        echo "  all                          — Run all tiers"
        echo "  compare                      — Show comparison table for all outputs"
        echo ""
        echo "Models for ollama: minimax-m2.7:cloud, glm-5.1:cloud, glm-4.7:cloud,"
        echo "  kimi-k2.5:cloud, deepseek-v3.2:cloud, qwen3-coder-next:cloud"
        ;;
esac
