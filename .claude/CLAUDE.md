# Claude Code Memory

**THIS IS REALLY CRITICAL: AVOID CREATING .MD FILE, THEY JUST MAKE NOISE AND COGNITIVE OVERLOAD**

## Claude Code Configuration Structure

**IMPORTANT: Configuration files are managed in dotfiles repository.**

### Directory Structure:

- **Configuration files** (version controlled):
  - `~/dotfiles/.claude/CLAUDE.md` - This file (personal instructions)
  - `~/dotfiles/.claude/settings.json` - Global settings and hooks
  - `~/dotfiles/.claude/hooks/` - Hook scripts (e.g., postgres-mcp-approval.sh)
  - `~/dotfiles/.claude/settings.local.json` - Local permissions

- **Symlinks in `~/.claude/`**:
  - `~/.claude/CLAUDE.md → ~/dotfiles/.claude/CLAUDE.md`
  - `~/.claude/settings.json → ~/dotfiles/.claude/settings.json`
  - `~/.claude/hooks → ~/dotfiles/.claude/hooks`
  - `~/.claude.json → ~/dotfiles/.claude/.claude.json` - Global MCP servers configuration

- **Runtime files** (NOT version controlled, stay in `~/.claude/`):
  - `history.jsonl` - Conversation history
  - `debug/` - Debug logs
  - `file-history/` - File change history
  - `projects/` - Project-specific data
  - `todos/` - Todo lists
  - `.credentials.json` - Authentication credentials

### MCP Server Configuration

**Global MCP servers** are configured in `~/.claude.json` (symlinked to `~/dotfiles/.claude/.claude.json`):

- Edit `~/dotfiles/.claude/.claude.json` under the `mcpServers` section
- These servers are available across all projects
- Examples: context7, postgres-local, postgres-staging, postgres-prod
- **Note**: This file is version controlled in dotfiles, but contains runtime data (project history, tips, etc.)
- Restart Claude Code after modifying MCP server configuration

**Project-specific MCP servers** can be configured in:

- `.mcp.json` files in project roots (version controlled with the project)
- Per-project settings in the `projects` section of `~/.claude.json` (auto-managed, not version controlled)

### When Modifying Configuration:

- ✅ Edit files in `~/dotfiles/.claude/` (they're the source of truth)
- ✅ Commit configuration changes to dotfiles git repository
- ❌ Don't edit runtime files (they're auto-managed by Claude Code)
- ❌ Don't commit credentials or history files

## System Environment

**Wayland Display Server:**

- Use `wl-copy` for copying to clipboard (not `xclip`)
- Example: `echo "text" | wl-copy`

## CRITICAL: Code-Test Feedback Loop

**ALWAYS test code you've produced. ALWAYS establish a "code" -> "test" -> "fix" feedback loop.**

When writing or modifying code:

1. Write/modify the code
2. Test it immediately (run tests, execute the code, verify behavior)
3. Fix any issues discovered during testing
4. Repeat until working correctly

Never consider code complete without testing it first. This applies to:

- New features
- Bug fixes
- Refactoring
- Configuration changes
- Database queries
- API endpoints
- Scripts

# 🚨 DATABASE QUERY PROTOCOL - MANDATORY 🚨

**STOP AND READ BEFORE ANY SQL QUERY**

## Rule: ALWAYS Check Schema FIRST - No Exceptions

Before EVERY SQL query (SELECT, INSERT, UPDATE, DELETE, etc.), you MUST verify the schema.

### Step 1: Check Schema Using MCP Resources

PostgreSQL MCP servers expose schema resources for every table. Use `ReadMcpResourceTool` to get the complete schema:

```typescript
// Example: Check item_revisions table schema
ReadMcpResourceTool({
  server: "postgres-prod", // or postgres-staging, postgres-local
  uri: "postgres://[credentials]/item_revisions/schema",
});
```

The schema resource returns:

- All column names and types
- Constraints (PRIMARY KEY, FOREIGN KEY, NOT NULL, etc.)
- Indexes
- Table relationships

### Step 2: Write Your Query Using Actual Column Names

Only after confirming the schema, write your SQL query using the correct column names and types.

### Why This Matters

❌ **Without schema check:**

```sql
SELECT sell_price_in_cents_excl_tax FROM item_revisions;
-- ERROR: column does not exist
```

✅ **With schema check:**

```sql
-- First check schema, discover it's JSONB
SELECT (item->>'sell_price_in_cents_excl_tax')::integer FROM item_revisions;
-- SUCCESS
```

### Alternative: Use information_schema (Fallback)

If MCP resources don't work for some reason:

```sql
-- Check table columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'your_table'
ORDER BY ordinal_position;

-- Check constraints
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'your_table';
```

## Consequences of Skipping Schema Checks

- ❌ Failed queries waste time and tokens
- ❌ Multiple error-retry cycles
- ❌ Looks unprofessional
- ❌ May corrupt data with wrong assumptions

## Remember

**"I think I know the schema" is NOT good enough. VERIFY IT EVERY TIME.**

# Context7 MCP Server for Library Documentation

**ALWAYS use Context7 when working with libraries to get up-to-date, version-specific documentation.**

Context7 is an MCP server that provides the latest documentation directly from official sources, preventing outdated code generation.

### When to Use Context7

Use Context7 when:

- Working with any library or framework (Next.js, React Query, MongoDB, FastAPI, etc.)
- Need current API documentation
- Want to ensure code uses latest best practices
- Checking for new features or breaking changes

### How to Use

**Two-step process (required for first use):**

1. Resolve library ID: `mcp__context7__resolve-library-id` with `libraryName`
2. Get documentation: `mcp__context7__get-library-docs` with the resolved ID

**Parameters for get-library-docs:**

- `context7CompatibleLibraryID` (required) - Exact library ID (e.g., `/mongodb/docs`, `/vercel/next.js`)
- `topic` (optional) - Focus on specific topic (e.g., "routing", "hooks", "authentication")
- `tokens` (optional, default 5000) - Max tokens to return

**Example workflow:**

```
User: "How do I use Next.js server actions?"

1. Call mcp__context7__resolve-library-id with libraryName="Next.js"
   → Returns library ID: "/vercel/next.js"

2. Call mcp__context7__get-library-docs with:
   - context7CompatibleLibraryID: "/vercel/next.js"
   - topic: "server actions"
   → Returns latest Next.js server actions documentation

3. Use the returned documentation to write accurate, up-to-date code
```

**User can also specify:**

- "use context7" or "use library X" in their prompt
- Direct library ID: "use library /supabase/supabase for API"

### Benefits

- ✅ Version-aware documentation (no outdated code)
- ✅ Fetches from official sources
- ✅ Prevents deprecated API usage
- ✅ Focused documentation via topic parameter
- ✅ Supports hundreds of popular libraries

### Important Notes

- Always resolve library ID first (unless user provides exact ID)
- Use `topic` parameter to narrow down large docs
- Context7 works without API key (with rate limits)
- For better performance, API key can be added to MCP config
