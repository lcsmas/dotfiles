# Linear Automation TUI - Implementation Plan

## Goal
Create a lazygit-style terminal UI for Linear automation with the following layout:

```
┌─────────────────────────────────────────────────────────────┐
│ Search: █                            [Semantic] / Fuzzy      │
├─────────────────────────────────────────────────────────────┤
│ ⚠️  Database behind - Last sync: 2025-10-11 00:01:23        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ > [HLP-123] Device not showing in loop                      │
│   Priority: 4  State: Triage  B2C  @John Doe                │
│                                                              │
│   [HLP-124] Wrong price displayed                           │
│   Priority: 2  State: In Progress  B2B Cleaq  @Jane Smith   │
│                                                              │
│   ...                                                        │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│ h: Help | f: Filter HelpTech | s: Sync DB | /: Search       │
└─────────────────────────────────────────────────────────────┘
```

## Features

### Top Search Bar
- Search input with blinking cursor
- Toggle between Semantic and Fuzzy search modes
- Tab key to switch search modes
- Visual indicator showing current mode

### Sync Status Bar
- Display last sync date from `.last-sync.json`
- Color-coded warning:
  - Green: Synced recently (< 1 hour)
  - Yellow: Needs sync (< 24 hours)
  - Red: Outdated (> 24 hours)
- Show "Database behind" if outdated

### Ticket List Viewport
- Load tickets from `solved-tickets-database.json` or `helptech-tickets.json`
- Display with color coding:
  - Priority colors (red for high priority >= 4)
  - State colors (green for "In Progress", yellow for "Triage")
  - Label colors (blue for B2C, magenta for B2B Cleaq, etc.)
- Scrollable with up/down arrows
- Selected ticket highlighted
- Show ticket identifier, title, priority, state, labels, assignee

### Keyboard Shortcuts Bar (Bottom)
- Display available shortcuts
- Key bindings:
  - `h`: Show help
  - `f`: Filter to show only HelpTech tickets (all states)
  - `s`: Sync database (run fetch-solved-tickets.sh)
  - `/`: Focus search bar
  - `Enter`: View ticket details / Analyze ticket
  - `Esc` / `Ctrl+C`: Quit
  - `Tab`: Toggle search mode
  - Arrow keys / `j`/`k`: Navigate list

## Implementation Steps

### Step 1: Project Setup
- [ ] Create `linear-automation/tui/` directory
- [ ] Initialize package.json with dependencies:
  - ink
  - react
  - @types/react
  - @types/bun
- [ ] Create basic `index.tsx` with Ink app skeleton
- [ ] Create launcher script `linear-tui.sh`
- [ ] Test: Ensure app launches and renders basic "Hello World"

### Step 2: Search Bar Component
- [ ] Create search input at top
- [ ] Add blinking cursor animation
- [ ] Show placeholder text when empty
- [ ] Add search mode toggle (Semantic/Fuzzy)
- [ ] Visual indicator for current mode
- [ ] Handle keyboard input
- [ ] Test: Can type, see cursor, toggle modes

### Step 3: Sync Status Bar
- [ ] Read `.last-sync.json` to get last sync date
- [ ] Calculate time difference from now
- [ ] Color-code based on age (green/yellow/red)
- [ ] Display formatted message
- [ ] Test: Shows correct status and colors

### Step 4: Ticket List Viewport
- [ ] Load tickets from JSON files
- [ ] Parse ticket data (identifier, title, priority, state, labels, assignee)
- [ ] Render ticket list with colors
- [ ] Implement scrolling with arrow keys
- [ ] Highlight selected ticket
- [ ] Handle empty state
- [ ] Test: Can see tickets, scroll, select

### Step 5: Keyboard Shortcuts Hint Bar
- [ ] Create bottom bar component
- [ ] Display shortcut hints
- [ ] Style similar to lazygit
- [ ] Test: Visible and readable

### Step 6: Filter Implementation
- [ ] Add filter state (show all / HelpTech only)
- [ ] Implement filter toggle with `f` key
- [ ] Filter tickets by HelpTech labels
- [ ] Update ticket count display
- [ ] Test: Filter works correctly

### Step 7: Search Integration
- [ ] Implement fuzzy search (local filtering)
- [ ] Call semantic-search.py for semantic mode
- [ ] Display search results in viewport
- [ ] Handle loading states
- [ ] Test: Both search modes work

### Step 8: Ticket Actions
- [ ] Implement ticket selection with Enter
- [ ] Launch Claude Code for analysis (like analyze-ticket.sh)
- [ ] View ticket details
- [ ] Copy ticket URL to clipboard
- [ ] Test: Actions work correctly

### Step 9: Database Sync
- [ ] Implement sync command (call fetch-solved-tickets.sh)
- [ ] Show progress indicator
- [ ] Update status bar after sync
- [ ] Handle errors gracefully
- [ ] Test: Sync works and updates status

### Step 10: Polish & Testing
- [ ] Add help modal (press `h`)
- [ ] Improve error handling
- [ ] Add loading states
- [ ] Test all features end-to-end
- [ ] Update README with TUI usage

## Tech Stack
- **Runtime**: Bun (matching tmux-menu)
- **UI Framework**: Ink (React for terminal)
- **Language**: TypeScript
- **Integration**: Shell scripts via child_process

## File Structure
```
linear-automation/
├── tui/
│   ├── index.tsx           # Main app entry
│   ├── components/
│   │   ├── SearchBar.tsx
│   │   ├── SyncStatus.tsx
│   │   ├── TicketList.tsx
│   │   └── ShortcutBar.tsx
│   ├── package.json
│   └── tsconfig.json
├── linear-tui.sh           # Launcher script
├── TUI_IMPLEMENTATION_PLAN.md  # This file
└── [existing scripts...]
```

## Color Scheme (matching lazygit style)
- Background: Terminal default
- Borders: Gray/dim
- Selected item: Green/cyan highlight
- Search mode indicator: Cyan (active), Gray (inactive)
- Status bar:
  - Green: OK/recent
  - Yellow: Warning
  - Red: Error/outdated
- Ticket colors:
  - Priority high: Red
  - State "In Progress": Green
  - State "Triage": Yellow
  - Labels: Blue (B2C), Magenta (B2B Cleaq), etc.

## Notes
- Test each step before proceeding to the next
- Reuse existing bash/python scripts where possible
- Match tmux-menu code style and patterns
- Focus on user experience and visual polish
