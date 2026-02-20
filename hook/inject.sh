#!/bin/bash
# BrainX V3 Auto-Inject Hook Script
# Runs on agent:bootstrap event

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAINX_V3_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="${WORKSPACE_DIR:-$1}"

# Configurable options (with defaults)
LIMIT="${BRAINX_INJECT_LIMIT:-5}"
TIER="${BRAINX_INJECT_TIER:-hot+warm}"
MIN_IMPORTANCE="${BRAINX_INJECT_MIN_IMPORTANCE:-5}"
AGENT_NAME="${AGENT_NAME:-unknown}"

# Output file
OUTPUT_FILE="$WORKSPACE_DIR/BRAINX_CONTEXT.md"

# Load environment
if [ -f "$BRAINX_V3_DIR/.env" ]; then
    export $(grep -v '^#' "$BRAINX_V3_DIR/.env" | xargs) 2>/dev/null || true
fi

# Check if brainx CLI is available
if [ ! -f "$BRAINX_V3_DIR/brainx-v3" ]; then
    echo "Error: brainx-v3 CLI not found at $BRAINX_V3_DIR/brainx-v3" >&2
    exit 1
fi

# Generate header
cat > "$OUTPUT_FILE" << EOF
# 🧠 BrainX V3 Context (Auto-Injected)

**Last updated:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')  
**Agent:** $AGENT_NAME  
**Query:** Recent memories ($TIER tier, importance >= $MIN_IMPORTANCE)

---

EOF

# Run brainx inject and append to file
if "$BRAINX_V3_DIR/brainx-v3" inject --limit "$LIMIT" --tier "$TIER" --minImportance "$MIN_IMPORTANCE" 2>/dev/null >> "$OUTPUT_FILE"; then
    echo "[brainx-auto-inject] Context injected to $OUTPUT_FILE" >&2
else
    echo "[brainx-auto-inject] Warning: Could not retrieve memories from BrainX" >&2
    echo "*No memories available or BrainX not configured*" >> "$OUTPUT_FILE"
fi

exit 0
