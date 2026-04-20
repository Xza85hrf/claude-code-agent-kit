---
name: browser-control
description: Browser automation and web interaction — navigate, click, extract text, fill forms, take screenshots, monitor network. Use when scraping web pages, testing UIs, processing URLs, filling forms, or any task requiring browser interaction. Prefer over WebFetch for rich pages. NOT for code-level browser testing (use webapp-testing) or static doc fetching (use context7).
argument-hint: "URL or browser task description"
allowed-tools: ["mcp__pinchtab__*"]
department: integration
---

# Browser Control via PinchTab

Enable: `bash .claude/scripts/mcp-profile.sh +pinchtab`

PinchTab is a **token-efficient browser control** MCP server (~800 tokens/page vs 10K+ for WebFetch). It uses Chrome DevTools Protocol for precise DOM manipulation with persistent browser profiles.

**Running on**: `localhost:9867` (systemd daemon: `pinchtab.service`)

## When to Use

| Signal | Use PinchTab | Don't Use |
|--------|-------------|-----------|
| Fetch & summarize a URL | Yes — `pinchtab_navigate` + `pinchtab_snapshot` | WebFetch for simple static pages |
| Fill a form / login | Yes — `pinchtab_fill` + `pinchtab_click` | Never manually |
| Take a screenshot | Yes — `pinchtab_screenshot` | Playwright for CI |
| Monitor network requests | Yes — `pinchtab_network` | Browser DevTools |
| Extract structured data | Yes — `pinchtab_find` + `pinchtab_get_text` | Firecrawl for bulk crawling |
| Test a web UI visually | Yes — navigate + screenshot | webapp-testing for assertions |
| Scrape authenticated sites | Yes — `pinchtab_connect_profile` | Firecrawl (no auth) |
| Bulk crawl 100+ pages | No — use Firecrawl `firecrawl_crawl` | PinchTab is single-page focused |
| URL ingestion / summarization | Yes — replaces WebFetch (5-10x fewer tokens) | WebFetch as fallback |

## Tool Reference

### Navigation & Pages
| Tool | Purpose | Key Params |
|------|---------|------------|
| `pinchtab_navigate` | Go to URL | `url`, optional `tabId` |
| `pinchtab_snapshot` | Get page DOM as clean text (~800 tokens) | `tabId` |
| `pinchtab_screenshot` | Capture visible page as PNG | `tabId`, `fullPage` |
| `pinchtab_pdf` | Export page as PDF | `tabId` |
| `pinchtab_wait_for_load` | Wait for page load | `tabId` |
| `pinchtab_wait_for_url` | Wait for URL change | `url`, `tabId` |

### Interaction
| Tool | Purpose | Key Params |
|------|---------|------------|
| `pinchtab_click` | Click element by selector | `selector`, `tabId` |
| `pinchtab_fill` | Fill input field | `selector`, `value`, `tabId` |
| `pinchtab_type` | Type text character by character | `selector`, `text`, `tabId` |
| `pinchtab_select` | Select dropdown option | `selector`, `value`, `tabId` |
| `pinchtab_hover` | Hover over element | `selector`, `tabId` |
| `pinchtab_focus` | Focus an element | `selector`, `tabId` |
| `pinchtab_scroll` | Scroll page or element | `direction`, `amount`, `tabId` |
| `pinchtab_press` | Press keyboard key | `key`, `tabId` |
| `pinchtab_keydown`/`pinchtab_keyup` | Hold/release key | `key`, `tabId` |
| `pinchtab_keyboard_type` | Type raw text (no selector) | `text`, `tabId` |
| `pinchtab_keyboard_inserttext` | Insert text at cursor | `text`, `tabId` |
| `pinchtab_dialog` | Handle alert/confirm/prompt dialogs | `accept`, `text`, `tabId` |

### Extraction
| Tool | Purpose | Key Params |
|------|---------|------------|
| `pinchtab_find` | Find elements matching selector | `selector`, `tabId` |
| `pinchtab_get_text` | Get text content of element | `selector`, `tabId` |
| `pinchtab_eval` | Execute JavaScript in page | `expression`, `tabId` |
| `pinchtab_cookies` | Get/set cookies | `tabId` |
| `pinchtab_network` | Get captured network requests | `tabId` |
| `pinchtab_network_detail` | Get details of specific request | `requestId`, `tabId` |
| `pinchtab_network_clear` | Clear network log | `tabId` |

### Session Management
| Tool | Purpose | Key Params |
|------|---------|------------|
| `pinchtab_connect_profile` | Connect with persistent profile (auth state) | `profileName` |
| `pinchtab_list_tabs` | List open tabs | — |
| `pinchtab_close_tab` | Close a tab | `tabId` |
| `pinchtab_health` | Check PinchTab server status | — |

### Waiting
| Tool | Purpose | Key Params |
|------|---------|------------|
| `pinchtab_wait` | Wait fixed time (ms) | `time` |
| `pinchtab_wait_for_selector` | Wait for element to appear | `selector`, `tabId` |
| `pinchtab_wait_for_text` | Wait for text to appear | `text`, `tabId` |
| `pinchtab_wait_for_function` | Wait for JS condition | `expression`, `tabId` |

## Common Patterns

### Fetch & Summarize URL
```
1. pinchtab_navigate → url
2. pinchtab_wait_for_load
3. pinchtab_snapshot → get clean text (~800 tokens)
4. Summarize in response
```

### Authenticated Scraping
```
1. pinchtab_connect_profile → "my-profile" (has saved cookies/auth)
2. pinchtab_navigate → authenticated URL
3. pinchtab_snapshot or pinchtab_find + pinchtab_get_text
```

### Form Filling
```
1. pinchtab_navigate → form URL
2. pinchtab_fill → each field
3. pinchtab_click → submit button
4. pinchtab_wait_for_load → wait for response
5. pinchtab_snapshot → verify result
```

### Visual Verification (Screenshot)
```
1. pinchtab_navigate → URL
2. pinchtab_wait_for_selector → key element
3. pinchtab_screenshot → capture PNG
4. Read the screenshot file for visual analysis
```

## PinchTab vs Alternatives

| Feature | PinchTab | WebFetch | Firecrawl | Playwright (Docker) |
|---------|----------|----------|-----------|-------------------|
| Token efficiency | ~800/page | ~10K/page | ~2K/page | N/A (binary) |
| Auth/cookies | Yes (profiles) | No | No | Yes |
| Click/fill/interact | Yes | No | No | Yes |
| JavaScript execution | Yes (eval) | No | No | Yes |
| Network monitoring | Yes | No | No | Yes |
| Screenshot | Yes | No | Yes | Yes |
| Bulk crawling | No (single-page) | No | Yes | No |
| MCP integration | Native | Native | Native | Docker Gateway |
| Always running | Daemon (systemd) | Built-in | Always-on | Docker container |

## Companion Tools

### browser-use (Vision-Based Browser Automation)
Enable: `bash .claude/scripts/mcp-profile.sh +browser-use`

Use when PinchTab's DOM-based approach fails — complex visual workflows, pages with dynamic rendering, or when you need AI-driven multi-step browser reasoning.

| Feature | PinchTab | browser-use |
|---------|----------|-------------|
| Approach | DOM selectors (fast, precise) | Screenshots + AI vision |
| Token cost | ~800/page | ~3-5K/action |
| Best for | Structured pages, scraping, forms | Complex workflows, visual UIs |
| CAPTCHA | No | Cloud option only |
| MCP tools | `pinchtab_*` | `browser_use_*` |

**Routing rule**: Try PinchTab first. If selectors fail or the page is heavily dynamic/visual, fall back to browser-use.

### Windows-MCP (Desktop GUI Automation)
Enable: `bash .claude/scripts/mcp-profile.sh +windows-mcp`

Use for non-browser tasks — controlling Windows desktop apps, file manager, system settings, or any GUI application.

| Capability | Tool |
|-----------|------|
| Mouse/keyboard simulation | `windows_mcp_*` |
| Window management | Launch, resize, focus apps |
| Screenshot | Capture desktop state |
| PowerShell | Execute system commands |
| File system | Navigate, manage files via GUI |

**Note**: Runs on Windows host. Available when Claude Code runs in WSL2 via VS Code.

## Security Notes

- PinchTab/browser-use control a real browser — treat as elevated privilege
- IDPI (injection protection) is disabled for open browsing; re-enable for production
- Token stored in `~/.pinchtab/config.json`
- Never expose PinchTab port (9867) to network — localhost only
- Persistent profiles store cookies/auth — handle like credentials
- Windows-MCP has full desktop access — confirm destructive ops with user
- browser-use can execute JS in pages — same security model as PinchTab eval
