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

# Check Node.js v18+
try {
    $nodeVersion = & node --version 2>&1
    $nodeMajor = [int](& node -e "process.stdout.write(String(parseInt(process.version.slice(1))))" 2>&1)
    if ($nodeMajor -lt 18) {
        Write-Host "  ERROR: Node.js v18+ required (found $nodeVersion). Install from https://nodejs.org" -ForegroundColor Red
        exit 1
    }
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

# Step 2: Select browser
Write-Host "`n[2/4] Selecting browser..." -ForegroundColor Yellow

# Helper: check if any of the given paths exist
function Find-Browser($paths) {
    foreach ($p in $paths) { if (Test-Path $p) { return $true } }
    return $false
}

$chromeInstalled = Find-Browser @(
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)
$edgeInstalled = Find-Browser @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
)
$firefoxInstalled = Find-Browser @(
    "${env:ProgramFiles}\Mozilla Firefox\firefox.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
)

# Build list of available browsers
$availBrowsers = @()
if ($chromeInstalled)  { $availBrowsers += @{ Key="chrome";  Label="Google Chrome";   Flag="" } }
if ($edgeInstalled)    { $availBrowsers += @{ Key="msedge";  Label="Microsoft Edge";  Flag="--browser msedge" } }
if ($firefoxInstalled) { $availBrowsers += @{ Key="firefox"; Label="Firefox";         Flag="--browser firefox" } }

$BrowserFlag = ""

if ($Browser -eq "auto") {
    # Interactive prompt — show only browsers that are actually installed
    if ($availBrowsers.Count -eq 0) {
        Write-Host "  ERROR: No supported browser found." -ForegroundColor Red
        Write-Host "  Install Chrome: https://www.google.com/chrome" -ForegroundColor Red
        Write-Host "  Install Edge:   pre-installed on Windows 10/11" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Browsers found on this system:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $availBrowsers.Count; $i++) {
        Write-Host "    [$($i+1)] $($availBrowsers[$i].Label)"
    }
    Write-Host ""

    do {
        $choice = Read-Host "  Enter number [1-$($availBrowsers.Count)]"
        $valid = $choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $availBrowsers.Count
        if (-not $valid) {
            Write-Host "  Invalid choice. Please enter a number between 1 and $($availBrowsers.Count)." -ForegroundColor Red
        }
    } while (-not $valid)

    $selected = $availBrowsers[[int]$choice - 1]
    $BrowserFlag = $selected.Flag
    Write-Host "  Selected: $($selected.Label)" -ForegroundColor Green

} else {
    # --Browser flag was explicitly passed — validate it is supported and installed
    $knownKeys = @("chrome", "msedge", "firefox")
    if ($knownKeys -notcontains $Browser) {
        Write-Host "  ERROR: Unknown browser '$Browser'. Supported values: chrome, msedge, firefox" -ForegroundColor Red
        exit 1
    }
    $match = $availBrowsers | Where-Object { $_.Key -eq $Browser }
    if (-not $match) {
        Write-Host "  ERROR: '$Browser' is recognised but not installed on this system." -ForegroundColor Red
        exit 1
    }
    $BrowserFlag = $match.Flag
    Write-Host "  Using: $($match.Label) (from -Browser flag)" -ForegroundColor Green
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

# Remove existing MCP server if present (try both user and local scope)
try { & claude mcp remove playwright -s user 2>&1 | Out-Null } catch {}
try { & claude mcp remove playwright        2>&1 | Out-Null } catch {}

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
