#!/usr/bin/env bash
# Claude Browser Agent — macOS/Linux Installer
# Usage: bash install.sh [--browser chrome|firefox|msedge]

set -e

SKILL_NAME="claude-browser-agent"
PROFILE_DIR="$HOME/.playwright-mcp-profile"
SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; GRAY='\033[0;37m'; NC='\033[0m'

# ── Parse args ────────────────────────────────────────────────────────────────
BROWSER_ARG=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --browser) BROWSER_ARG="$2"; shift 2 ;;
    *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1 ;;
  esac
done

echo ""
echo -e "${CYAN}=== Claude Browser Agent Installer ===${NC}"

# ── Step 1: Find Node.js v18+ ─────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[1/4] Checking Node.js...${NC}"

# Returns 0 and prints path if binary is node v18+, else returns 1
valid_node() {
  local bin="$1"
  [[ -x "$bin" ]] || return 1
  local major
  major=$("$bin" -e "console.log(parseInt(process.version.slice(1)))" 2>/dev/null) || return 1
  [[ "$major" -ge 18 ]] || return 1
  echo "$bin"
}

NODE_BIN=""
NODE_CANDIDATES=()

# 1. node already in PATH
command -v node >/dev/null 2>&1 && NODE_CANDIDATES+=("$(command -v node)")

# 2. nvm nodes sorted newest-first by major version
if [[ -d "$HOME/.nvm/versions/node" ]]; then
  while IFS= read -r ver; do
    NODE_CANDIDATES+=("$HOME/.nvm/versions/node/$ver/bin/node")
  done < <(
    ls "$HOME/.nvm/versions/node" 2>/dev/null \
      | awk -F'[v.]' '{ printf "%d %s\n", $2+0, $0 }' \
      | sort -k1,1rn \
      | awk '{ print $2 }'
  )
fi

# 3. Homebrew (Apple Silicon first, then Intel)
NODE_CANDIDATES+=("/opt/homebrew/bin/node" "/usr/local/bin/node")

# 4. Volta
[[ -d "$HOME/.volta/bin" ]] && NODE_CANDIDATES+=("$HOME/.volta/bin/node")

for candidate in "${NODE_CANDIDATES[@]}"; do
  result=$(valid_node "$candidate") && { NODE_BIN="$result"; break; } || true
done

if [[ -z "$NODE_BIN" ]]; then
  echo -e "  ${RED}ERROR: Node.js v18+ not found.${NC}"
  echo "  Install from https://nodejs.org  or via nvm: https://github.com/nvm-sh/nvm"
  exit 1
fi

NODE_VERSION=$("$NODE_BIN" -e "console.log(process.version)")
echo -e "  ${GREEN}Found: $NODE_VERSION at $NODE_BIN${NC}"

# Find npx that lives alongside this node
NPX_BIN="$(dirname "$NODE_BIN")/npx"
if [[ ! -x "$NPX_BIN" ]]; then
  echo -e "  ${RED}ERROR: npx not found alongside node at $(dirname "$NODE_BIN")${NC}"
  exit 1
fi

# Verify npx works when explicitly run under our node binary
# (bypasses the #!/usr/bin/env node shebang which could resolve to an older system node)
NPX_VERSION=$("$NODE_BIN" "$NPX_BIN" --version 2>/dev/null) || {
  echo -e "  ${RED}ERROR: npx at $NPX_BIN failed when run under $NODE_BIN${NC}"
  exit 1
}
echo -e "  ${GREEN}npx: v$NPX_VERSION${NC}"

# ── Step 2: Find Claude Code CLI ──────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/4] Finding Claude Code CLI...${NC}"

CLAUDE_BIN=""

# Check PATH first
command -v claude >/dev/null 2>&1 && CLAUDE_BIN="$(command -v claude)"

# macOS: search versioned app bundle paths (newest version first)
if [[ -z "$CLAUDE_BIN" && -d "$HOME/Library/Application Support/Claude/claude-code" ]]; then
  while IFS= read -r bin; do
    [[ -x "$bin" ]] && { CLAUDE_BIN="$bin"; break; }
  done < <(
    find "$HOME/Library/Application Support/Claude/claude-code" \
      -maxdepth 3 -name "claude" -type f -print 2>/dev/null \
      | sort -rV
  )
fi

if [[ -z "$CLAUDE_BIN" ]]; then
  echo -e "  ${RED}ERROR: Claude Code CLI not found.${NC}"
  echo "  Install from https://claude.ai/claude-code and make sure it is in PATH."
  exit 1
fi

echo -e "  ${GREEN}Found: $CLAUDE_BIN${NC}"

# ── Step 3: Select browser ────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[3/4] Selecting browser...${NC}"

AVAIL_KEYS=(); AVAIL_LABELS=(); AVAIL_FLAGS=()

if [[ "$OSTYPE" == "darwin"* ]]; then
  [[ -e "/Applications/Google Chrome.app" ]]   && { AVAIL_KEYS+=("chrome");  AVAIL_LABELS+=("Google Chrome");   AVAIL_FLAGS+=(""); }
  [[ -e "/Applications/Firefox.app" ]]          && { AVAIL_KEYS+=("firefox"); AVAIL_LABELS+=("Firefox");         AVAIL_FLAGS+=("--browser firefox"); }
  [[ -e "/Applications/Microsoft Edge.app" ]]   && { AVAIL_KEYS+=("msedge");  AVAIL_LABELS+=("Microsoft Edge");  AVAIL_FLAGS+=("--browser msedge"); }
else
  command -v google-chrome        >/dev/null 2>&1 && { AVAIL_KEYS+=("chrome");  AVAIL_LABELS+=("Google Chrome");   AVAIL_FLAGS+=(""); }
  command -v google-chrome-stable >/dev/null 2>&1 && [[ "${AVAIL_KEYS[*]}" != *"chrome"* ]] \
    && { AVAIL_KEYS+=("chrome");  AVAIL_LABELS+=("Google Chrome");   AVAIL_FLAGS+=(""); }
  command -v firefox              >/dev/null 2>&1 && { AVAIL_KEYS+=("firefox"); AVAIL_LABELS+=("Firefox");         AVAIL_FLAGS+=("--browser firefox"); }
  command -v microsoft-edge       >/dev/null 2>&1 && { AVAIL_KEYS+=("msedge");  AVAIL_LABELS+=("Microsoft Edge");  AVAIL_FLAGS+=("--browser msedge"); }
fi

if [[ "${#AVAIL_KEYS[@]}" -eq 0 ]]; then
  echo -e "  ${RED}ERROR: No supported browser found on this system.${NC}"
  echo "  Install Google Chrome: https://www.google.com/chrome"
  echo "  Install Firefox:       https://www.mozilla.org"
  exit 1
fi

BROWSER_FLAG=""

if [[ -n "$BROWSER_ARG" ]]; then
  # --browser flag provided — validate it is supported and installed
  MATCHED=false
  for i in "${!AVAIL_KEYS[@]}"; do
    if [[ "${AVAIL_KEYS[$i]}" == "$BROWSER_ARG" ]]; then
      BROWSER_FLAG="${AVAIL_FLAGS[$i]}"
      echo -e "  ${GREEN}Using: ${AVAIL_LABELS[$i]} (from --browser flag)${NC}"
      MATCHED=true
      break
    fi
  done
  if [[ "$MATCHED" == false ]]; then
    if [[ "$BROWSER_ARG" =~ ^(chrome|firefox|msedge)$ ]]; then
      echo -e "  ${RED}ERROR: '$BROWSER_ARG' is recognised but not installed on this system.${NC}"
    else
      echo -e "  ${RED}ERROR: Unknown browser '$BROWSER_ARG'. Supported values: chrome, firefox, msedge${NC}"
    fi
    exit 1
  fi
else
  # Interactive prompt — show only installed browsers
  echo "  Browsers found on this system:"
  echo ""
  for i in "${!AVAIL_KEYS[@]}"; do
    echo "    [$((i+1))] ${AVAIL_LABELS[$i]}"
  done
  echo ""
  while true; do
    read -rp "  Enter number [1-${#AVAIL_KEYS[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#AVAIL_KEYS[@]} )); then
      idx=$((choice - 1))
      BROWSER_FLAG="${AVAIL_FLAGS[$idx]}"
      echo -e "  ${GREEN}Selected: ${AVAIL_LABELS[$idx]}${NC}"
      break
    else
      echo -e "  ${RED}  Invalid choice. Please enter a number between 1 and ${#AVAIL_KEYS[@]}.${NC}"
    fi
  done
fi

# ── Step 4: Configure MCP server + install skill ──────────────────────────────
echo ""
echo -e "${YELLOW}[4/4] Configuring MCP server and installing skill...${NC}"

# Create persistent browser profile directory
mkdir -p "$PROFILE_DIR"
echo -e "  ${GREEN}Profile directory: $PROFILE_DIR${NC}"

# Remove any mcpServers key from settings.json — the correct location is ~/.claude.json via `claude mcp add`
SETTINGS_JSON="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS_JSON" ]] && command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS_JSON" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
if "mcpServers" in data:
    del data["mcpServers"]
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("  Cleaned up stray mcpServers key from ~/.claude/settings.json")
PYEOF
fi

# Remove any existing playwright MCP registrations (user scope and local/project scope)
"$CLAUDE_BIN" mcp remove playwright -s user 2>/dev/null || true
"$CLAUDE_BIN" mcp remove playwright        2>/dev/null || true

# Build the MCP command args.
# We register as: node /path/to/npx @playwright/mcp@latest [--browser X] --user-data-dir DIR
# Using explicit node + npx paths ensures Claude Code uses the correct Node version
# regardless of what `node` resolves to in its environment (GUI apps don't load shell profiles).
MCP_ARGS=("$NODE_BIN" "$NPX_BIN" "@playwright/mcp@latest")
if [[ -n "$BROWSER_FLAG" ]]; then
  read -ra BROWSER_PARTS <<< "$BROWSER_FLAG"
  MCP_ARGS+=("${BROWSER_PARTS[@]}")
fi
MCP_ARGS+=("--user-data-dir" "$PROFILE_DIR")

echo -e "  ${GRAY}Command: ${MCP_ARGS[*]}${NC}"
"$CLAUDE_BIN" mcp add -s user playwright -- "${MCP_ARGS[@]}"
echo -e "  ${GREEN}MCP server registered (user scope — works from any directory)${NC}"

# Install skill file
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/skill/SKILL.md" "$SKILL_DIR/SKILL.md"
echo -e "  ${GREEN}Skill installed: $SKILL_DIR/SKILL.md${NC}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=== Installation Complete ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Restart Claude Code to activate the MCP server"
echo "  2. Try: 'open google.com' or 'scan my X feed'"
echo "  3. First time on a site? Log in manually in the browser window"
echo ""
echo -e "${GRAY}Browser sessions persist at: $PROFILE_DIR${NC}"
echo ""
