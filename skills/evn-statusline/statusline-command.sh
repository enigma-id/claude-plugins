#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model_id=$(echo "$input" | jq -r '.model.id')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
transcript=$(echo "$input" | jq -r '.transcript_path')

# Abbreviated directory (last 2 segments)
if [[ "$cwd" == "$HOME"* ]]; then
  cwd_display="~${cwd#$HOME}"
else
  cwd_display="$cwd"
fi
dir_short=$(echo "$cwd_display" | awk -F'/' '{if(NF<=2) print $0; else print $(NF-1)"/"$NF}')

# Git branch and status (skip optional locks)
git_info=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || echo "detached")
  if git -C "$cwd" --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; then
    # Clean
    git_info=$(printf "\033[32m(%s)\033[0m" "$branch")
  else
    # Dirty
    git_info=$(printf "\033[33m(%s*)\033[0m" "$branch")
  fi
fi

# Model name (short form)
model_short=$(echo "$model_id" | sed -E 's/^(kr|ag)\///' | sed 's/claude-//' | sed 's/-202[0-9].*//')

# Parse active skills from transcript (last 100 lines)
skills=""
if [ -f "$transcript" ]; then
  skills=$(tail -100 "$transcript" 2>/dev/null | grep -o '<command-name>/[^<]*</command-name>' | sed 's/<command-name>\/\([^<]*\)<\/command-name>/\1/' | grep '^skills:' | sed 's/^skills://' | sort -u | tr '\n' ',' | sed 's/,$//')
fi

if [ -n "$skills" ]; then
  skills_display="$skills"
else
  skills_display="no skills"
fi

# Context usage with color
ctx_display=""
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  if [ "$used_int" -gt 80 ]; then
    ctx_display=$(printf "\033[31m%d%%\033[0m" "$used_int")
  else
    ctx_display=$(printf "%d%%" "$used_int")
  fi
fi

# Build output
output="[$dir_short]"
[ -n "$git_info" ] && output="$output $git_info"
output="$output | $model_short | $skills_display"
[ -n "$ctx_display" ] && output="$output | $ctx_display"

echo "$output"
