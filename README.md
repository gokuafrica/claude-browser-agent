# Claude Browser Agent

Give Claude Code the ability to control a real browser — navigate websites, read feeds, fill forms, click buttons, and post content. Uses Microsoft's Playwright MCP server under the hood.

## How It Works

Claude Code communicates with websites through the **Model Context Protocol (MCP)**. The Playwright MCP server launches a real browser (Edge/Chrome) and exposes tools like `browser_navigate`, `browser_click`, `browser_type`, and `browser_snapshot` that Claude can call directly from conversations.

```
You (natural language) → Claude Code (reasoning) → Playwright MCP (browser control) → Website
```

The browser runs in **headed mode** (visible window) with a **persistent profile**, so:
- You can see everything Claude does in real-time
- You log in once per site and sessions persist across restarts
- You handle CAPTCHAs/2FA manually, then Claude takes over

### Architecture Decision: Why Playwright MCP Over browser-use?

We evaluated several options:

| Tool | Requires API Key? | Claude Integration | Best For |
|------|-------------------|-------------------|----------|
| **Playwright MCP** | No | Native MCP | Claude Max/Pro users |
| browser-use | Yes (LLM API key) | MCP or Python | API users with own key |
| Pinchtab | No | None (HTTP API) | Custom agent builders |
| Claude Computer Use | No (but API-only) | Native | API users, non-browser tasks |

**Playwright MCP won** because:
1. No separate LLM API key needed — Claude Code IS the brain
2. First-class MCP support by Microsoft — actively maintained
3. Accessibility-tree-based (fast, cheap on tokens) vs screenshot-based (slow, expensive)
4. Works with Claude Max/Pro subscriptions, not just API billing

## Prerequisites

- **Claude Code** installed and authenticated
- **Node.js** (v18+) with npm/npx
- **Microsoft Edge** or **Google Chrome** installed
- Windows 10/11, macOS, or Linux

## Quick Start

### 1. Install the Playwright MCP server

```bash
claude mcp add -s user playwright -- npx @playwright/mcp@latest --user-data-dir ~/.playwright-mcp-profile
```

If you use **Edge** (no Chrome installed):
```bash
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser msedge --user-data-dir ~/.playwright-mcp-profile
```

### 2. Restart Claude Code

The MCP server initializes at session start. Restart Claude Code to activate it.

### 3. Install the skill (optional)

Copy the skill file to your Claude skills directory:

```bash
# Windows
mkdir %USERPROFILE%\.claude\skills\claude-browser-agent
copy skill\SKILL.md %USERPROFILE%\.claude\skills\claude-browser-agent\SKILL.md

# macOS/Linux
mkdir -p ~/.claude/skills/claude-browser-agent
cp skill/SKILL.md ~/.claude/skills/claude-browser-agent/SKILL.md
```

### 4. Test it

In Claude Code, try:
- "Open google.com"
- "Navigate to x.com and show me my feed"
- "Go to reddit.com and read the top posts on r/technology"

## What Claude Can Do With This

- **Navigate** to any URL
- **Read** page content via accessibility tree snapshots
- **Click** buttons, links, and interactive elements
- **Type** into forms, search bars, text areas
- **Extract** structured data from pages (via JavaScript evaluation)
- **Take screenshots** for visual verification
- **Manage tabs** (open, close, switch)
- **Upload files** to file inputs
- **Wait** for elements to appear or disappear

## Session Persistence

Your browser profile is stored at `~/.playwright-mcp-profile`. This means:
- Cookies and login sessions survive across Claude Code restarts
- Site preferences and settings are remembered
- You only need to log in once per website

To reset the profile (clear all sessions):
```bash
# Windows
rmdir /s %USERPROFILE%\.playwright-mcp-profile

# macOS/Linux
rm -rf ~/.playwright-mcp-profile
```

## Configuration Options

The Playwright MCP server supports many flags. Common ones:

```bash
# Use a specific browser
--browser msedge          # Microsoft Edge
--browser chrome          # Google Chrome
--browser firefox         # Firefox
--browser webkit          # WebKit/Safari

# Run headless (no visible window)
--headless

# Set viewport size
--viewport-size 1920x1080

# Emulate a device
--device "iPhone 15"

# Ignore HTTPS errors (useful for local dev)
--ignore-https-errors

# Save session traces for debugging
--save-trace
```

## Limitations

- **CAPTCHAs and 2FA**: Claude cannot solve these — you handle them manually in the visible browser window
- **Anti-bot detection**: Some sites detect automation. The headed mode with a persistent profile helps, but aggressive anti-bot systems may still block access
- **Shadow DOM**: Some modern web frameworks hide elements inside Shadow DOM roots that the accessibility tree can't reach
- **Rate limits**: Websites may rate-limit automated interactions
- **Platform ToS**: Automating actions on social media may violate their terms of service. Use responsibly.

## Troubleshooting

**"Chromium distribution not found"**
```bash
# Install the browser Playwright needs
npx playwright install chrome
# Or use Edge instead (--browser msedge)
```

**MCP server shows "Failed to connect"**
- Restart Claude Code — MCP servers initialize at session start
- Check that npx is available: `npx --version`

**Browser opens but Claude can't interact**
- The page may still be loading — Claude waits automatically
- Shadow DOM elements may be invisible to the accessibility tree
- Try `browser_take_screenshot` to see what Claude sees

## License

MIT
