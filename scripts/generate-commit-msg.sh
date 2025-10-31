#!/bin/bash

set -e

# Get the staged diff with color
STAGED_DIFF=$(git diff --cached --color=always)

# Check if there are staged changes
if [ -z "$STAGED_DIFF" ]; then
    echo "No staged changes found. Please stage your changes with 'git add' first."
    exit 1
fi

# Show staged changes for review
echo "Staged changes:"
echo "$STAGED_DIFF"
echo ""

# Construct the prompt for AI review of changes
REVIEW_PROMPT="Review the following staged changes and provide feedback on whether they are ready for commit. Point out any potential issues, improvements, or confirm if they look good.

Staged changes:
$STAGED_DIFF

Provide concise feedback."

# Run opencode to review the changes
REVIEW=$(opencode run "$REVIEW_PROMPT")

# Output the AI review
echo "AI Review:"
echo "$REVIEW"
echo ""

# Ask for confirmation before generating commit message (default y)
read -p "Do you want to generate a commit message for these changes? (y/n): " -n 1 -r
echo
if [ -z "$REPLY" ]; then REPLY='y'; fi
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
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

# Check if commit message was generated successfully
if [ -z "$COMMIT_MESSAGE" ]; then
    echo "Failed to generate commit message. Please check the staged changes or try again."
    exit 1
fi

# Output the generated commit message for review
echo "Generated commit message:"
echo "$COMMIT_MESSAGE"
echo ""

# Ask for confirmation before committing (default y)
read -p "Do you want to commit with this message? (y/n): " -n 1 -r
echo
if [ -z "$REPLY" ]; then REPLY='y'; fi
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Commit cancelled."
    exit 0
fi

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