#!/bin/bash

set -e

# Function to display loading animation
show_loading_animation() {
    local message="$1"
    printf '%s' "$message" >&2
    while true; do
        for i in "|" "/" "-" "\\"; do
            printf '\b%s' "$i" >&2
            sleep 0.1
        done
    done
}

# Function to run command with loading animation
run_with_loading() {
    local message="$1"
    shift
    show_loading_animation "$message" &
    local spinner_pid=$!
    local output
    output=$(timeout 300 "$@" 2>&1)
    local exit_code=$?
    kill $spinner_pid 2>/dev/null
    if [ $exit_code -eq 0 ]; then
        printf '\b✓\n' >&2
    else
        printf '\b✗\n' >&2
    fi
    echo "$output"
}

# Function to sanitize diff content to prevent exposing sensitive data
sanitize_diff() {
    local diff_content="$1"
    # Remove or obfuscate potential secrets/credentials in the diff
    # This is a basic implementation that filters out common patterns
    echo "$diff_content" | sed \
        -e 's/\(password\|secret\|token\|key\|authorization\|api_key\|client_secret\|access_token\|private_key\|secret_key\)=.*/\1=***REDACTED***/gi' \
        -e 's/\(PASSWORD\|SECRET\|TOKEN\|KEY\|AUTHORIZATION\|API_KEY\|CLIENT_SECRET\|ACCESS_TOKEN\|PRIVATE_KEY\|SECRET_KEY\):.*/\1:***REDACTED***/gi'
}



# Function to check if there are staged changes
check_staged_changes() {
    if git diff --cached --quiet; then
        echo "No staged changes found. Please stage your changes with 'git add' first."
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if required tools are available
check_dependencies() {
    if ! command_exists "opencode"; then
        echo "Error: opencode is not installed or not in PATH." >&2
        echo "Please install opencode or configure your AI service." >&2
        return 1
    fi
    if ! command_exists "bat"; then
        echo "Error: bat is not installed or not in PATH." >&2
        return 1
    fi
    return 0
}

# Function to display staged files
display_staged_files() {
    local staged_files="$1"

    echo -e "\033[1mStaged changes:\033[0m"
    echo "$staged_files"
    echo ""
}

# Function to get AI review of changes
get_ai_review() {
    local staged_diff="$1"
    
    # Sanitize the diff to prevent exposing sensitive data
    local sanitized_diff
    sanitized_diff=$(sanitize_diff "$staged_diff")
    
    local review_prompt="Review the following staged changes and provide feedback on whether they are ready for commit. Point out any potential issues, improvements, or confirm if they look good.

Staged changes:
$sanitized_diff

Provide concise feedback."

    # Run opencode to get the review with loading animation
    local review
    review=$(run_with_loading "Getting AI review of changes... " opencode run "$review_prompt")

    # Display header with green text and AI review as markdown
    echo
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                              \033[1;32mAI REVIEW SUMMARY\033[0m                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo

    # Render the AI review as markdown
    # Create a temporary file with the review content
    local temp_file
    temp_file=$(mktemp)
    echo "$review" > "$temp_file"
    
    if command_exists "bat"; then
        bat --language md --style=plain --paging=never "$temp_file"
    else
        echo "$review"
    fi
    
    # Clean up the temporary file
    rm "$temp_file"
    echo ""

    return 0
}

# Function to confirm before generating commit message
confirm_before_generation() {
    read -p "Do you want to generate a commit message for these changes? (y/n): " -n 1 -r
    echo

    # Default to 'y' if no input is provided
    if [ -z "$REPLY" ]; then
        REPLY='y'
    fi

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
}

# Function to get recent commit messages for style reference
get_recent_commits() {
    git log --oneline -10
}

# Function to generate commit message using AI
generate_commit_message() {
    local staged_diff="$1"
    local recent_commits="$2"
    
    # Sanitize the diff to prevent exposing sensitive data
    local sanitized_diff
    sanitized_diff=$(sanitize_diff "$staged_diff")

    local prompt="Generate a concise commit message for the following staged changes. Follow the project's commit message style based on these recent commits:

Recent commits:
$recent_commits

Staged changes:
$sanitized_diff

Output only the commit message in the format: <type>(<scope>): <description>

Where type is one of: feat, fix, docs, style, refactor, test, chore"

    # Run opencode to get the commit message with loading animation
    local commit_message
    commit_message=$(run_with_loading "Generating commit message... " opencode run "$prompt")

    # Remove all newlines to ensure single-line output
    commit_message=$(echo "$commit_message" | tr -d '\n')

    # Check if commit message was generated successfully
    if [ -z "$commit_message" ]; then
        echo "Failed to generate commit message. Please check the staged changes or try again."
        exit 1
    fi

    echo "$commit_message"
}

# Function to confirm before committing
confirm_before_commit() {
    local commit_message="$1"

    # Display header in normal table format and commit message in normal color
    echo
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           GENERATED COMMIT MESSAGE                           ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo

    # Display the commit message in normal color
    echo "$commit_message"
    echo ""

    read -p "Do you want to commit with this message? (y/n): " -n 1 -r
    echo

    # Default to 'y' if no input is provided
    if [ -z "$REPLY" ]; then
        REPLY='y'
    fi

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Commit cancelled."
        exit 0
    fi
}

# Main script execution
main() {
    # Check dependencies
    check_dependencies || exit 1
    
    # Get the staged file changes for display
    local staged_files
    staged_files=$(git diff --cached --name-status --color=always)

    # Get the full staged diff for AI processing
    local staged_diff
    staged_diff=$(git diff --cached --color=always)

    # Check if there are staged changes
    check_staged_changes

    # Show staged changes for review
    display_staged_files "$staged_files"

    # Get AI review of changes
    get_ai_review "$staged_diff"

    # Ask for confirmation before generating commit message
    confirm_before_generation

    # Get recent commit messages for style reference
    local recent_commits
    recent_commits=$(get_recent_commits)

    # Generate commit message
    local commit_message
    commit_message=$(generate_commit_message "$staged_diff" "$recent_commits")

    # Ask for confirmation before committing
    confirm_before_commit "$commit_message"

    # Commit with the generated message
    git commit -m "$commit_message"
}

# Execute the main function
main

