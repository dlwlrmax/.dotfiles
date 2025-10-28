#!/bin/bash

set -e

# Get the staged diff
STAGED_DIFF=$(git diff --cached)

# Check if there are staged changes
if [ -z "$STAGED_DIFF" ]; then
    echo "No staged changes found. Please stage your changes with 'git add' first."
    exit 1
fi

# Get recent commit messages for style reference
RECENT_COMMITS=$(git log --oneline -10)

# Construct the prompt for opencode
PROMPT="Generate a concise commit message for the following staged changes. Follow the project's commit message style based on these recent commits:

Recent commits:
$RECENT_COMMITS

Staged changes:
$STAGED_DIFF

Output only the commit message in the format: <type>(<scope>): <description>

Where type is one of: feat, fix, docs, style, refactor, test, chore"

# Run opencode to generate the commit message
COMMIT_MESSAGE=$(opencode run "$PROMPT")

# Remove all newlines to ensure single-line output
COMMIT_MESSAGE=$(echo "$COMMIT_MESSAGE" | tr -d '\n')

# Output the generated commit message
echo "$COMMIT_MESSAGE"

# Commit with the generated message
git commit -m "$COMMIT_MESSAGE"

# Copy to clipboard
if command -v wl-copy >/dev/null 2>&1; then
    echo "$COMMIT_MESSAGE" | wl-copy
    echo "Commit message copied to clipboard."
elif command -v xclip >/dev/null 2>&1; then
    echo "$COMMIT_MESSAGE" | xclip -selection clipboard
    echo "Commit message copied to clipboard."
else
    echo "Clipboard tool not found. Install wl-copy (Wayland) or xclip (X11)."
fi