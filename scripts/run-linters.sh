#!/bin/bash

set -e

# Function to display loading animation with proper signaling
show_loading_animation() {
    local message="$1"
    local signal_file="$2"
    local delay=0.1
    
    printf '%s' "$message"
    while [ -f "$signal_file" ]; do
        for i in '|' '/' '-' '-'; do
            sleep $delay
            printf '\b%s' "$i"
            sleep $delay
        done
    done
    printf '\b✓\n'
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print colored output
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Function to check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    # Check for essential tools
    if ! command_exists "opencode"; then
        missing_tools+=("opencode")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_warning "Missing tools: ${missing_tools[*]}"
        print_info "AI analysis features will be disabled."
        return 1
    fi
    
    return 0
}

# Function to wrap text for table display
wrap_text() {
    local text="$1"
    local width="${2:-76}"  # Default width is 76 characters (80 - 4 for borders)
    
    # Use fold to wrap text at the specified width
    echo "$text" | fold -w "$width" | sed 's/$/ /'
}

# Function to display AI analysis with header in table format and content as markdown
display_ai_analysis() {
    local title="$1"
    local content="$2"
    local max_title_width=78
    
    # Calculate padding for the title to center it
    local padded_title="$title"
    local title_length=${#title}
    if [ "$title_length" -lt $max_title_width ]; then
        local total_padding=$((max_title_width - title_length))
        local left_padding=$(((total_padding + 1) / 2))
        local right_padding=$((total_padding - left_padding))
        padded_title=$(printf "%*s%s%*s" $left_padding "" "$title" $right_padding "")
    fi
    
    echo
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║${padded_title}║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo
    
    # Render the AI analysis as markdown
    # Create a temporary file with the content
    local temp_file
    temp_file=$(mktemp)
    echo "$content" > "$temp_file"
    
    # Use the markdown rendering script to format the content
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local markdown_script="$script_dir/render-markdown.sh"
    
    if [ -f "$markdown_script" ]; then
        "$markdown_script" "$temp_file"
    else
        # Fallback to displaying as regular text if markdown script is not available
        echo "$content"
    fi
    
    # Clean up the temporary file
    rm "$temp_file"
    echo
}

# Function to check and run a linter/formatter
run_tool() {
    local tool_name="$1"
    local tool_cmd="$2"
    local additional_args="${3:-}"
    
    if command_exists "$tool_name"; then
        print_info "Running $tool_name..."
        $tool_cmd "$additional_args"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            print_success "$tool_name completed successfully"
            return 0
        else
            print_error "$tool_name failed with exit code $exit_code"
            return $exit_code
        fi
    else
        print_warning "$tool_name is not installed or not in PATH"
        return 1
    fi
}

# Function to check and run prettier
run_prettier() {
    local target_path="${1:-.}"
    
    if command_exists "prettier"; then
        print_info "Running prettier..."
        prettier --check "$target_path"
        print_success "Prettier check completed"
        return 0
    else
        print_warning "prettier is not installed or not in PATH"
        return 1
    fi
}

# Function to run prettier with write option
run_prettier_write() {
    local target_path="${1:-.}"
    
    if command_exists "prettier"; then
        print_info "Running prettier --write..."
        prettier --write "$target_path"
        print_success "Prettier formatting completed"
        return 0
    else
        print_warning "prettier is not installed or not in PATH"
        return 1
    fi
}

# Function to check and run ESLint
run_eslint() {
    local target_path="${1:-.}"
    
    if command_exists "eslint"; then
        print_info "Running eslint..."
        eslint "$target_path"
        print_success "ESLint completed"
        return 0
    else
        print_warning "eslint is not installed or not in PATH"
        return 1
    fi
}

# Function to run ESLint with fix option
run_eslint_fix() {
    local target_path="${1:-.}"
    
    if command_exists "eslint"; then
        print_info "Running eslint --fix..."
        eslint --fix "$target_path"
        print_success "ESLint fix completed"
        return 0
    else
        print_warning "eslint is not installed or not in PATH"
        return 1
    fi
}

# Function to check and run Black (Python formatter)
run_black() {
    local target_path="${1:-.}"
    
    if command_exists "black"; then
        print_info "Running black..."
        black --check "$target_path"
        print_success "Black check completed"
        return 0
    else
        print_warning "black is not installed or not in PATH"
        return 1
    fi
}

# Function to run black with formatting
run_black_format() {
    local target_path="${1:-.}"
    
    if command_exists "black"; then
        print_info "Running black format..."
        black "$target_path"
        print_success "Black formatting completed"
        return 0
    else
        print_warning "black is not installed or not in PATH"
        return 1
    fi
}

# Function to check and run ruff (Python linter)
run_ruff() {
    local target_path="${1:-.}"
    
    if command_exists "ruff"; then
        print_info "Running ruff..."
        ruff check "$target_path"
        print_success "Ruff check completed"
        return 0
    else
        print_warning "ruff is not installed or not in PATH"
        return 1
    fi
}

# Function to run ruff with fix
run_ruff_fix() {
    local target_path="${1:-.}"
    
    if command_exists "ruff"; then
        print_info "Running ruff --fix..."
        ruff check --fix "$target_path"
        print_success "Ruff fix completed"
        return 0
    else
        print_warning "ruff is not installed or not in PATH"
        return 1
    fi
}

# Function to check and run shellcheck
run_shellcheck() {
    local target_path="${1:-.}"
    
    if command_exists "shellcheck"; then
        print_info "Running shellcheck..."
        find "$target_path" -name "*.sh" -type f -exec shellcheck {} \;
        print_success "Shellcheck completed"
        return 0
    else
        print_warning "shellcheck is not installed or not in PATH"
        return 1
    fi
}

# Function to check and run fmt (Go formatter)
run_go_fmt() {
    if command_exists "go"; then
        print_info "Running go fmt..."
        go fmt ./...
        print_success "Go formatting completed"
        return 0
    else
        print_warning "go is not installed or not in PATH"
        return 1
    fi
}

# Function to check and run rustfmt
run_rustfmt() {
    if command_exists "rustfmt"; then
        print_info "Running rustfmt..."
        cargo fmt --check
        print_success "Rustfmt check completed"
        return 0
    else
        print_warning "rustfmt is not installed or not in PATH"
        return 1
    fi
}

# Function to run rustfmt with format option
run_rustfmt_format() {
    if command_exists "rustfmt"; then
        print_info "Running rustfmt --format..."
        cargo fmt
        print_success "Rust formatting completed"
        return 0
    else
        print_warning "rustfmt is not installed or not in PATH"
        return 1
    fi
}

# Function to analyze linter results with AI
analyze_with_ai() {
    local tool_name="$1"
    local tool_output="$2"
    
    if command_exists "opencode"; then
        local ai_prompt="Analyze the $tool_name output and provide a summary of issues found and recommendations.

$tool_name output:
$tool_output

Provide a concise summary of the issues found and recommendations for fixing them."
        
        # Create a temporary file to signal animation completion
        local signal_file
        signal_file=$(mktemp)
        echo "running" > "$signal_file"

        # Start loading animation in background using the common function
        show_loading_animation "Analyzing $tool_name output with AI... " "$signal_file" &
        local loading_pid=$!

        # Run opencode to get the analysis (this will eventually end the loading animation)
        local ai_analysis
        ai_analysis=$(opencode run "$ai_prompt" 2>/dev/null)
        
        # Signal the animation to stop and wait for it to finish
        rm "$signal_file"
        wait $loading_pid 2>/dev/null || true
        
        # Display AI analysis in a table format
        display_ai_analysis "AI ANALYSIS FOR $tool_name" "$ai_analysis"
    else
        print_warning "opencode is not available. Skipping AI analysis."
    fi
}

# Function to run all available linters/formatters
run_all() {
    print_info "Running all available linters and formatters..."
    
    local tools_ran=0
    local tools_failed=0
    
    # Check JavaScript/TypeScript files
    if [ -f "package.json" ] || [ -n "$(find . -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' | head -1)" ]; then
        if run_prettier; then
            ((tools_ran++))
        else
            ((tools_failed++))
        fi
        if run_eslint; then
            ((tools_ran++))
        else
            ((tools_failed++))
        fi
    fi
    
    # Check Python files
    if [ -n "$(find . -name '*.py' | head -1)" ]; then
        if run_black; then
            ((tools_ran++))
        else
            ((tools_failed++))
        fi
        if run_ruff; then
            ((tools_ran++))
        else
            ((tools_failed++))
        fi
    fi
    
    # Check Shell scripts
    if [ -n "$(find . -name '*.sh' | head -1)" ]; then
        if run_shellcheck; then
            ((tools_ran++))
        else
            ((tools_failed++))
        fi
    fi
    
    # Check Go files
    if [ -n "$(find . -name '*.go' | head -1)" ]; then
        if run_go_fmt; then
            ((tools_ran++))
        else
            ((tools_failed++))
        fi
    fi
    
    # Check Rust files
    if [ -n "$(find . -name '*.rs' | head -1)" ]; then
        if run_rustfmt; then
            ((tools_ran++))
        else
            ((tools_failed++))
        fi
    fi
    
    print_info "Summary: $tools_ran tools ran successfully, $tools_failed tools failed or not available"
}

# Display help information
show_help() {
    echo "Usage: $0 [OPTIONS] [PATH]"
    echo
    echo "Options:"
    echo "  -a, --all           Run all available linters and formatters"
    echo "  -p, --prettier      Run prettier check"
    echo "  --prettier-write    Run prettier with write option"
    echo "  -e, --eslint        Run eslint"
    echo "  --eslint-fix        Run eslint with fix option"
    echo "  -b, --black         Run black check"
    echo "  --black-format      Run black with format option"
    echo "  -r, --ruff          Run ruff check"
    echo "  --ruff-fix          Run ruff with fix option"
    echo "  -s, --shellcheck    Run shellcheck"
    echo "  --go-fmt            Run go fmt"
    echo "  --rustfmt           Run rustfmt check"
    echo "  --rustfmt-format    Run rustfmt with format option"
    echo "  -h, --help          Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --all                    # Run all linters/formatters in current directory"
    echo "  $0 --eslint ./src          # Run eslint on ./src directory"
    echo "  $0 --prettier-write .      # Run prettier write on current directory"
}

# Main function
main() {
    local target_path="."
    local action=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                action="all"
                shift
                ;;
            -p|--prettier)
                action="prettier"
                shift
                ;;
            --prettier-write)
                action="prettier_write"
                shift
                ;;
            -e|--eslint)
                action="eslint"
                shift
                ;;
            --eslint-fix)
                action="eslint_fix"
                shift
                ;;
            -b|--black)
                action="black"
                shift
                ;;
            --black-format)
                action="black_format"
                shift
                ;;
            -r|--ruff)
                action="ruff"
                shift
                ;;
            --ruff-fix)
                action="ruff_fix"
                shift
                ;;
            -s|--shellcheck)
                action="shellcheck"
                shift
                ;;
            --go-fmt)
                action="go_fmt"
                shift
                ;;
            --rustfmt)
                action="rustfmt"
                shift
                ;;
            --rustfmt-format)
                action="rustfmt_format"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                print_error "Unknown option $1"
                show_help
                exit 1
                ;;
            *)
                target_path="$1"
                shift
                ;;
        esac
    done
    
    # Run the specified action
    case $action in
        "all")
            run_all
            ;;
        "prettier")
            run_prettier "$target_path"
            ;;
        "prettier_write")
            run_prettier_write "$target_path"
            ;;
        "eslint")
            run_eslint "$target_path"
            ;;
        "eslint_fix")
            run_eslint_fix "$target_path"
            ;;
        "black")
            run_black "$target_path"
            ;;
        "black_format")
            run_black_format "$target_path"
            ;;
        "ruff")
            run_ruff "$target_path"
            ;;
        "ruff_fix")
            run_ruff_fix "$target_path"
            ;;
        "shellcheck")
            run_shellcheck "$target_path"
            ;;
        "go_fmt")
            run_go_fmt
            ;;
        "rustfmt")
            run_rustfmt
            ;;
        "rustfmt_format")
            run_rustfmt_format
            ;;
        "")
            print_info "No action specified. Use -h or --help for usage information."
            show_help
            exit 1
            ;;
    esac
}

# Execute the main function
main "$@"
