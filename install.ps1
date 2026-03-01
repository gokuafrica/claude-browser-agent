# Claude Browser Agent — Installer
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

param(
    [string]$Browser = "auto"
)

$ErrorActionPreference = "Stop"
$SkillName = "claude-browser-agent"
$ProfileDir = "$env:USERPROFILE\.playwright-mcp-profile"
$SkillDir = "$env:USERPROFILE\.claude\skills\$SkillName"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "`n=== Claude Browser Agent Installer ===" -ForegroundColor Cyan

# Step 1: Check prerequisites
Write-Host "`n[1/4] Checking prerequisites..." -ForegroundColor Yellow

# Check Node.js
try {
    $nodeVersion = & node --version 2>&1
    Write-Host "  Node.js: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Node.js not found. Install from https://nodejs.org" -ForegroundColor Red
    exit 1
}

# Check Claude Code
try {
    $claudeVersion = & claude --version 2>&1
    Write-Host "  Claude Code: $claudeVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Claude Code not found. Install from https://claude.com/claude-code" -ForegroundColor Red
    exit 1
}

# Step 2: Detect browser
Write-Host "`n[2/4] Detecting browser..." -ForegroundColor Yellow

$BrowserFlag = ""
if ($Browser -eq "auto") {
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    $chromeProgFiles = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    $chromeProgFilesX86 = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $edgeProgFiles = "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"

    if (Test-Path $chromePath) {
        Write-Host "  Found: Google Chrome (local)" -ForegroundColor Green
    } elseif (Test-Path $chromeProgFiles) {
        Write-Host "  Found: Google Chrome (Program Files)" -ForegroundColor Green
    } elseif (Test-Path $chromeProgFilesX86) {
        Write-Host "  Found: Google Chrome (Program Files x86)" -ForegroundColor Green
    } elseif (Test-Path $edgePath) {
        Write-Host "  Found: Microsoft Edge" -ForegroundColor Green
        $BrowserFlag = "--browser msedge"
    } elseif (Test-Path $edgeProgFiles) {
        Write-Host "  Found: Microsoft Edge" -ForegroundColor Green
        $BrowserFlag = "--browser msedge"
    } else {
        Write-Host "  ERROR: No supported browser found. Install Chrome or Edge." -ForegroundColor Red
        exit 1
    }
} elseif ($Browser -eq "edge") {
    $BrowserFlag = "--browser msedge"
    Write-Host "  Using: Microsoft Edge (manual)" -ForegroundColor Green
} elseif ($Browser -eq "chrome") {
    Write-Host "  Using: Google Chrome (manual)" -ForegroundColor Green
} elseif ($Browser -eq "firefox") {
    $BrowserFlag = "--browser firefox"
    Write-Host "  Using: Firefox (manual)" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Unknown browser '$Browser'. Use: auto, chrome, edge, firefox" -ForegroundColor Red
    exit 1
}

# Step 3: Configure MCP server
Write-Host "`n[3/4] Configuring Playwright MCP server..." -ForegroundColor Yellow

# Create persistent profile directory
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    Write-Host "  Created profile directory: $ProfileDir" -ForegroundColor Green
} else {
    Write-Host "  Profile directory exists: $ProfileDir" -ForegroundColor Green
}

# Remove existing MCP server if present
try {
    & claude mcp remove playwright 2>&1 | Out-Null
} catch {}

# Build MCP args
$mcpArgs = @("@playwright/mcp@latest")
if ($BrowserFlag) {
    $parts = $BrowserFlag -split " "
    $mcpArgs += $parts
}
$mcpArgs += "--user-data-dir"
$mcpArgs += $ProfileDir

# Add MCP server
$addCmd = "claude mcp add -s user playwright -- npx $($mcpArgs -join ' ')"
Write-Host "  Running: $addCmd" -ForegroundColor DarkGray
& claude mcp add -s user playwright -- npx @args $mcpArgs 2>&1
Write-Host "  MCP server registered" -ForegroundColor Green

# Step 4: Install skill
Write-Host "`n[4/4] Installing skill..." -ForegroundColor Yellow

if (-not (Test-Path $SkillDir)) {
    New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null
}
Copy-Item "$ScriptDir\skill\SKILL.md" "$SkillDir\SKILL.md" -Force
Write-Host "  Skill installed to: $SkillDir" -ForegroundColor Green

# Done
Write-Host "`n=== Installation Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart Claude Code to activate the MCP server"
Write-Host "  2. Try: 'open google.com' or 'scan my X feed'"
Write-Host "  3. First time visiting a site? Log in manually in the browser window"
Write-Host ""
Write-Host "Your browser sessions persist at: $ProfileDir" -ForegroundColor DarkGray
Write-Host ""
