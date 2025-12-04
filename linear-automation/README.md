# Linear Ticket Automation

Automate fetching Linear HelpTech tickets, analyze them with Claude Code, and build a searchable database of solved tickets with their solutions.

## Setup

### 1. Get Your Linear API Key

1. Go to [Linear Settings → API](https://linear.app/settings/api)
2. Click "Create new key" under Personal API keys
3. Copy your API key (starts with `lin_api_`)

### 2. Configure the Scripts

```bash
cd linear-automation
cp .env.example .env
# Edit .env and add your Linear API key
```

### 3. Install Dependencies

The scripts require `jq` and `curl`:

```bash
# Ubuntu/Debian
sudo apt-get install jq curl

# macOS
brew install jq
```

## Usage

### Working with Active Tickets (Triage & In Progress)

#### Option 1: Interactive Workflow (Recommended)

Run the automated workflow to fetch tickets, select one, and solve it with Claude Code:

```bash
./analyze-ticket.sh
```

This will:
1. Fetch latest triage/in-progress tickets
2. Display a list of available tickets
3. Let you select which ticket to solve
4. Launch Claude Code with the ticket context
5. Claude Code will analyze and provide a solution

#### Option 2: Manual Fetch

Just fetch tickets without the interactive workflow:

```bash
./fetch-linear-tickets.sh
```

This saves all active HelpTech tickets to `helptech-tickets.json`.

### Building a Solutions Database

#### Fetch Solved Tickets

Build a database of **ALL** solved HelpTech tickets with their solutions (from comments):

**First-time setup (fetch ALL historical tickets):**
```bash
./fetch-solved-tickets.sh --full
```

**Regular updates (fetch only new/updated tickets):**
```bash
./fetch-solved-tickets.sh
```

This will:
- **Full sync:** Fetch ALL solved HelpTech tickets using pagination (no limit!)
- **Incremental sync:** Only fetch tickets updated since last run
- Include all comments where solutions are documented
- Save to `solved-tickets-database.json`
- Track sync state in `.last-sync.json`
- Show summary statistics

**How it works:**
- Uses cursor-based pagination to fetch ALL tickets (50 per page)
- First run or `--full` flag: fetches everything from scratch
- Subsequent runs: only fetches tickets updated since last sync
- Automatically merges new tickets with existing database
- Deduplicates by ticket ID (newer data wins)

#### Search the Solutions Database

**Semantic Search (Recommended):**

True semantic search using AI embeddings - understands meaning and context:

```bash
# Search in natural language (English or French)
./semantic-search.sh "device not appearing in loop" 5
./semantic-search.sh "prix incorrect cleaq" 5

# Returns JSON with top 5 most relevant tickets
```

**Features:**
- ✅ Understands meaning, not just keywords
- ✅ Works in both English and French
- ✅ Finds related tickets even with different wording
- ✅ Returns similarity scores
- ✅ Auto-rebuilds index when database updates
- ✅ Filters out bot noise (only real user comments)

**First time:** Downloads ~80MB model (cached for future use)
**Index building:** ~9 seconds for 613 tickets
**Search speed:** < 1 second

**Fuzzy Search (Fallback):**

Interactive mode with menu:

```bash
./view-solutions.sh
```

Command-line mode (character-based matching):

```bash
# List all solved tickets
./view-solutions.sh --list

# Filter by label
./view-solutions.sh --list "B2C"
./view-solutions.sh --list "B2B Cleaq"

# Fuzzy search (keyword matching)
./view-solutions.sh --search "icloud"
./view-solutions.sh --filter-json "keyword"

# View specific ticket with all comments
./view-solutions.sh --view 5
```

## Workflow Tips

### Solving New Tickets

1. Run `./analyze-ticket.sh` to see active tickets
2. Select a ticket to solve
3. Claude Code will analyze it using HelpTech guidelines from `~/.claude/CLAUDE.md`
4. Claude will attempt to replicate the bug before fixing
5. After solving, document the solution in Linear comments

### Learning from Past Solutions

Before solving a new ticket, search the solutions database:

```bash
# Semantic search (best results)
./semantic-search.sh "describe the issue in natural language" 5

# Example searches (English or French)
./semantic-search.sh "device not showing in loop" 5
./semantic-search.sh "appareil manquant dans loop" 5
./semantic-search.sh "wrong price cleaq" 3

# Fuzzy search (for exact terms)
./view-solutions.sh --search "your search term"
./view-solutions.sh --list "B2C"
```

This helps you:
- Find solutions to similar problems
- Learn common patterns
- Avoid repeating mistakes
- Speed up resolution time

## Customization

### Filtering Different Ticket States

Edit `fetch-linear-tickets.sh` and modify the GraphQL query on line 15:

```graphql
# Change "Triage" to any state name
filter: { state: { name: { eq: "In Progress" }}}
```

### Adding More Ticket Fields

Add fields to the GraphQL query in `fetch-linear-tickets.sh`:

```graphql
issues(filter: ...) {
  nodes {
    ...
    labels {
      name
    }
    comments {
      nodes {
        body
      }
    }
  }
}
```

## Files

### Scripts
- `fetch-linear-tickets.sh` - Fetches active HelpTech tickets (Triage/In Progress)
- `fetch-solved-tickets.sh` - Fetches solved tickets with comments for the database
- `analyze-ticket.sh` - Interactive workflow to solve tickets with Claude Code
- `view-solutions.sh` - Browse and search the solutions database (fuzzy search)
- `semantic-search.sh` - Semantic search wrapper (auto-builds index)
- `semantic-search.py` - Core semantic search implementation
- `build-semantic-index.py` - Builds embeddings index for semantic search

### Data Files (auto-generated)
- `helptech-tickets.json` - Active tickets cache
- `solved-tickets-database.json` - Complete database of solved tickets with solutions
- `solved-tickets.index` - Prebuilt embeddings index for semantic search (~1.8MB)
- `.last-sync.json` - Metadata tracking last sync timestamp for incremental updates
- `.env` - Your Linear API key (create from `.env.example`)

## Troubleshooting

**Error: LINEAR_API_KEY not set**
- Make sure you created `.env` from `.env.example`
- Verify your API key is correct

**Error fetching tickets**
- Check your API key is valid
- Verify you have access to the team/workspace
- Check Linear API status

**No tickets found**
- Verify you have tickets in the filtered states
- Check the state and label names match exactly (case-sensitive)

**Solutions database is empty**
- Run `./fetch-solved-tickets.sh --full` first to build the complete database
- Make sure you have solved tickets in your Linear workspace
- Check that tickets have the HelpTech labels (B2C, B2B Cleaq, etc.)

**Incremental sync not working**
- Delete `.last-sync.json` and run `./fetch-solved-tickets.sh --full` to reset
- Check that the file has valid JSON with `lastSyncDate` field

## Future Enhancements

### Webhook Support (Planned)

Instead of polling Linear's API, you can use **webhooks** for real-time updates:

**Benefits:**
- Instant notifications when tickets are updated
- No polling delays
- Lower API usage
- More efficient

**How it would work:**
1. Set up a simple HTTP server to receive webhook events
2. Configure webhook in Linear Settings → API → Webhooks
3. Listen for `Issue` and `Comment` events
4. Automatically update the database when tickets are solved/updated

**Linear Webhook Events Available:**
- Issue created/updated/deleted
- Comment created/updated/deleted
- State changes (when ticket moves to "Done")

This would eliminate the need to run `fetch-solved-tickets.sh` periodically - the database would update automatically in real-time!

For webhook setup documentation, see: https://linear.app/developers/webhooks
