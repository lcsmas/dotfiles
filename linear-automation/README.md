# Linear Ticket Automation

Automate fetching Linear triage tickets and analyze them with Claude Code.

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

### Option 1: Interactive Workflow (Recommended)

Run the automated workflow to fetch tickets, select one, and prepare it for analysis:

```bash
./analyze-ticket.sh
```

This will:
1. Fetch latest triage tickets
2. Display a list of available tickets
3. Let you select which ticket to analyze
4. Create a `current-ticket-context.md` file with the ticket details
5. Show you how to ask Claude Code for analysis

### Option 2: Manual Fetch

Just fetch tickets without the interactive workflow:

```bash
./fetch-linear-tickets.sh
```

This saves all triage tickets to `triage-tickets.json`.

## Analyzing Tickets with Claude Code

After running `./analyze-ticket.sh`, you can ask Claude Code:

```
Analyze the ticket in linear-automation/current-ticket-context.md and provide a solution
```

Claude Code will provide:
- Problem summary
- Root cause analysis
- Proposed solution
- Implementation steps
- Testing considerations
- Potential risks

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

- `fetch-linear-tickets.sh` - Fetches tickets from Linear API
- `analyze-ticket.sh` - Interactive workflow for ticket analysis
- `triage-tickets.json` - Cached ticket data (auto-generated)
- `current-ticket-context.md` - Selected ticket context (auto-generated)
- `.env` - Your Linear API key (create from `.env.example`)

## Troubleshooting

**Error: LINEAR_API_KEY not set**
- Make sure you created `.env` from `.env.example`
- Verify your API key is correct

**Error fetching tickets**
- Check your API key is valid
- Verify you have access to the team/workspace
- Check Linear API status

**No triage tickets found**
- Verify you have tickets in "Triage" state
- Check the state name matches exactly (case-sensitive)
