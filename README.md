# Claude Browser Agent

Give Claude Code the ability to control a real browser — navigate websites, read feeds, fill forms, click buttons, and post content.

## How It Works

This sets up a browser that Claude Code can control directly from your conversations. A visible browser window opens on your screen, and Claude navigates it, reads pages, clicks things, and types — just like you would, but hands-free.

```
You (natural language) → Claude Code → Browser → Website
```

- You can **watch everything** Claude does in real-time
- You **log in once** per site and sessions persist across restarts
- You handle CAPTCHAs/2FA manually, then Claude takes over

## What Can It Do?

- **Browse** any website — navigate, scroll, go back
- **Read** pages — articles, feeds, dashboards, search results
- **Click** buttons, links, menus, and interactive elements
- **Type** into forms, search bars, text areas, compose boxes
- **Extract** data from pages into structured formats
- **Post** content on social media (with your confirmation)
- **Fill out** forms across multiple fields
- **Manage tabs** — open, close, switch between them
- **Upload files** to file inputs
- **Take screenshots** for visual verification

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- [Node.js](https://nodejs.org) v18+ (comes with npx)
- **Microsoft Edge** or **Google Chrome**
- Windows 10/11, macOS, or Linux

## Quick Start

### Option A: Run the installer (Windows)

```powershell
git clone https://github.com/gokuafrica/claude-browser-agent.git
cd claude-browser-agent
powershell -ExecutionPolicy Bypass -File install.ps1
```

The installer auto-detects your browser, configures everything, and installs the skill.

### Option B: Manual setup

**1. Register the browser server with Claude Code:**

```bash
# If you have Google Chrome:
claude mcp add -s user playwright -- npx @playwright/mcp@latest --user-data-dir ~/.playwright-mcp-profile

# If you use Microsoft Edge instead:
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser msedge --user-data-dir ~/.playwright-mcp-profile
```

**2. Install the skill (optional but recommended):**

```bash
# Windows
mkdir %USERPROFILE%\.claude\skills\claude-browser-agent
copy skill\SKILL.md %USERPROFILE%\.claude\skills\claude-browser-agent\SKILL.md

# macOS/Linux
mkdir -p ~/.claude/skills/claude-browser-agent
cp skill/SKILL.md ~/.claude/skills/claude-browser-agent/SKILL.md
```

**3. Restart Claude Code** to activate.

**4. Try it out:**

- "Open google.com"
- "Go to x.com and show me my feed"
- "Read the top posts on reddit"

## Logging In to Sites

The browser Claude controls is **separate from your regular browser** — it has its own profile, so you'll need to log in to your accounts the first time.

1. Ask Claude to open the site (e.g., "open twitter.com")
2. A browser window appears on your screen
3. Click "Sign in" and enter your credentials **directly in the browser window**
4. Once logged in, Claude takes over

Your sessions persist at `~/.playwright-mcp-profile`, so you only log in once per site.

To clear all saved sessions:
```bash
# Windows
rmdir /s %USERPROFILE%\.playwright-mcp-profile

# macOS/Linux
rm -rf ~/.playwright-mcp-profile
```

## Configuration

You can customize the browser behavior by modifying the MCP server flags. Remove the existing server and re-add with new flags:

```bash
claude mcp remove playwright
claude mcp add -s user playwright -- npx @playwright/mcp@latest [flags] --user-data-dir ~/.playwright-mcp-profile
```

Common flags:

| Flag | What it does |
|------|-------------|
| `--browser msedge` | Use Edge instead of Chrome |
| `--browser firefox` | Use Firefox |
| `--headless` | Run without a visible window |
| `--viewport-size 1920x1080` | Set the browser window size |
| `--device "iPhone 15"` | Emulate a mobile device |
| `--save-trace` | Save session traces for debugging |

## Limitations

- **CAPTCHAs and 2FA** — Claude can't solve these. You handle them in the browser window.
- **Anti-bot detection** — Some sites block automation. The visible browser with a persistent profile helps, but aggressive systems may still flag you.
- **Shadow DOM** — Some modern sites hide elements in ways Claude can't always see. Claude falls back to screenshots when this happens.
- **Platform ToS** — Automating social media may violate terms of service. Use responsibly.

## Troubleshooting

**"Chromium distribution not found"**
```bash
npx playwright install chrome
# Or switch to Edge: --browser msedge
```

**"Failed to connect"**
- Restart Claude Code — the browser server starts when Claude Code starts
- Verify npx works: `npx --version`

**Browser opens but nothing happens**
- The page may still be loading — give it a few seconds
- Ask Claude to take a screenshot to see the current state

## License

MIT
