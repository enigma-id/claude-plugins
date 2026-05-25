---
name: evn-statusline
description: Configure EVN-specific statusline for Claude Code with ClickUp task tracking and git branch info
triggers:
  - statusline
  - setup statusline
  - configure statusline
---

# EVN Statusline Setup

Configures Claude Code statusline to display:
- Current ClickUp task (from branch name pattern)
- Git branch and status
- Project context

## Setup

When this skill is invoked, it will:

1. Copy `statusline-command.sh` from the skill directory to `~/.claude/statusline-command.sh`
2. Make the script executable
3. Configure Claude Code to use the statusline script via `claude config set statusline.command ~/.claude/statusline-command.sh`
4. Test the statusline output
5. Verify setup is working

The script file is included in the skill package at `skills/evn-statusline/statusline-command.sh`.

## Statusline Features

### Current Implementation

The EVN statusline displays:
- **Directory** — Last 2 path segments (abbreviated)
- **Git Branch** — Current branch with color-coded status
  - Green `(branch)` — Clean working directory
  - Yellow `(branch*)` — Uncommitted changes
- **Model** — Short model name (e.g., `sonnet-4`, `opus-4`)
- **Active Skills** — Currently loaded skills from transcript
- **Context Usage** — Percentage with red warning at >80%

### Example Output

```
[claude-plugins] (main) | sonnet-4 | evn-golang,evn-database | 45%
[svc-warehouse] (feature/add-api*) | opus-4 | evn-golang,evn-clickup | 78%
```

## Usage

Run this skill once after installing EVN plugins:

```bash
/evn-statusline
```

The skill will:
1. Check if statusline script already exists
2. Create or update `~/.claude/statusline-command.sh`
3. Configure Claude Code settings
4. Test the statusline output
5. Confirm setup complete

## Statusline Script

The script (`statusline-command.sh`) receives JSON input from Claude Code:

```json
{
  "workspace": {
    "current_dir": "/Users/alifamri/Works/Enigma/svc-warehouse"
  },
  "model": {
    "id": "kr/claude-sonnet-4"
  },
  "context_window": {
    "used_percentage": 45.2
  },
  "transcript_path": "/Users/alifamri/.claude/sessions/abc123.jsonl"
}
```

**Key Features:**
- Parses JSON input with `jq`
- Extracts active skills from transcript (last 100 lines)
- Color-codes git status (green=clean, yellow=dirty)
- Warns when context usage >80% (red)
- Abbreviates directory paths
- Shortens model names

**Dependencies:**
- `jq` — JSON parsing
- `git` — Branch and status detection
- `bash` — Script execution

## Manual Setup (Alternative)

If you prefer manual setup:

1. Create `~/.claude/statusline-command.sh`:
   ```bash
   touch ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Add the script content (see above)

3. Configure Claude Code:
   ```bash
   claude config set statusline.command ~/.claude/statusline-command.sh
   ```

## Troubleshooting

### Statusline not showing
- Verify script exists: `ls -la ~/.claude/statusline-command.sh`
- Check permissions: `chmod +x ~/.claude/statusline-command.sh`
- Test script manually with sample JSON:
  ```bash
  echo '{"workspace":{"current_dir":"'$PWD'"},"model":{"id":"claude-sonnet-4"},"context_window":{"used_percentage":45},"transcript_path":""}' | ~/.claude/statusline-command.sh
  ```
- Verify config: `claude config get statusline.command`

### jq not found
- Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)
- Verify: `which jq`

### Skills not detected
- Skills are parsed from transcript (last 100 lines)
- Only shows skills with pattern `<command-name>/skills:*</command-name>`
- May take a few turns to appear after skill activation

### Git status not showing
- Ensure you're in a git repository: `git status`
- Check git is in PATH: `which git`

### Context percentage missing
- Context data comes from Claude Code JSON input
- Only available in active sessions
- May be empty in some contexts

## Customization

Edit `~/.claude/statusline-command.sh` to customize:

**Add ClickUp task ID extraction:**
```bash
# After line 23 (branch detection), add:
if [[ "$branch" =~ CU-[0-9a-z]+ ]]; then
  task_id="${BASH_REMATCH[0]}"
  branch="[$task_id] $branch"
fi
```

**Add Kubernetes context:**
```bash
# After line 10 (extract data), add:
k8s_ctx=$(kubectl config current-context 2>/dev/null || echo "")
# In output section (line 62), add:
[ -n "$k8s_ctx" ] && output="$output | k8s:$k8s_ctx"
```

**Add timestamp:**
```bash
# After line 10, add:
timestamp=$(date +%H:%M)
# In output section, add:
output="$output | $timestamp"
```

**Change color scheme:**
```bash
# Line 26 (clean): \033[32m = green
# Line 29 (dirty): \033[33m = yellow
# Line 53 (high context): \033[31m = red
# Use: 30=black, 31=red, 32=green, 33=yellow, 34=blue, 35=magenta, 36=cyan, 37=white
```

## Best Practices

1. **Clean Commits** — Statusline shows dirty state (`*`) — commit before switching tasks

2. **Project Switching** — Statusline shows project name for quick context when switching repos

3. **Monitor Context** — Watch for red context % warning (>80%) to avoid compaction

4. **Active Skills** — Statusline shows which skills are loaded in current session
