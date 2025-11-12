#!/bin/bash

# Function to render markdown with a simple approach that handles basic elements
simple_render_markdown() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo "File not found: $file"
        return 1
    fi

    local in_code_block=false
    local code_block_lang=""

    while IFS= read -r line || [ -n "$line" ]; do  # Handle last line without newline
        # Check for code block start
        if [[ $line =~ ^\`\`\`(.*)$ ]] && [ "$in_code_block" = false ]; then
            in_code_block=true
            code_block_lang="${BASH_REMATCH[1]}"
            echo -e "\033[1;30;47m Code Block (${code_block_lang:-txt}) \033[0m"
            continue
        # Check for code block end
        elif [[ $line =~ ^\`\`\`$ ]] && [ "$in_code_block" = true ]; then
            in_code_block=false
            continue
        # If in code block, render with code styling
        elif [ "$in_code_block" = true ]; then
            echo -e "\033[1;30;47m$line\033[0m"
            continue
        # Check for headings
        elif [[ $line =~ ^#{1,6}[[:space:]]+(.*) ]]; then
            local level
            level=$(echo "${BASH_REMATCH[0]}" | sed 's/[^#]//g' | wc -c)
            local content="${BASH_REMATCH[1]}"

            if [ "$level" -le 2 ]; then
                # H1 and H2: Bold with visual separation
                echo -e "\033[1;32m$content\033[0m"
            elif [ "$level" -eq 3 ]; then
                # H3: Just bold
                echo -e "\033[1m$content\033[0m"
            else
                # H4 and above: Just slightly emphasized
                echo -e "\033[36m$content\033[0m"
            fi
        # Check for list items
        elif [[ $line =~ ^[[:space:]]*[\-\*][[:space:]]+(.*) ]]; then
            local content="${BASH_REMATCH[1]}"
            echo -e "  \033[1;32m•\033[0m $content"
        elif [[ $line =~ ^[[:space:]]*[0-9]+[.][[:space:]]+(.*) ]]; then
            local content="${BASH_REMATCH[1]}"
            echo -e "  \033[1;32m→\033[0m $content"
        # Check for quotes
        elif [[ $line =~ ^[[:space:]]*"> "[[:space:]]*(.*) ]]; then
            local content="${BASH_REMATCH[1]}"
            echo -e "  \033[3;33m|$content\033[0m"
        else
            # Process bold text (**text**) - addressing SC2001 by using parameter expansion
            local formatted_line="$line"
            # Replace **text** with bold formatting using a loop to handle multiple occurrences
            while [[ $formatted_line =~ \*\*([^*]+)\*\* ]]; do
                local content="${BASH_REMATCH[1]}"
                local replacement="\033[1m${content}\033[0m"
                formatted_line="${formatted_line/\*\*${content}\*\*/$replacement}"
            done

            # Process inline code (`text`) - extract content between backticks and apply formatting
            local backtick
            backtick=$(printf '\047')  # Octal for backtick character
            while [[ $formatted_line == *"$backtick"* ]]; do
                local prefix="${formatted_line%%"$backtick"*}"
                local suffix="${formatted_line#*"$backtick"}"
                local content="${suffix%%"$backtick"*}"
                local remainder="${suffix#*"$backtick"}"
                
                if [[ -n "$content" ]]; then
                    local replacement="${prefix}\033[1;30;47m${content}\033[0m${remainder}"
                    formatted_line="$replacement"
                else
                    break  # No more valid patterns found
                fi
            done

            echo -e "$formatted_line"
        fi
    done < "$file"
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS] <markdown_file>"
    echo
    echo "Render markdown files in the terminal with basic formatting."
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo
    echo "Features:"
    echo "  - Headings (h1, h2, h3)"
    echo "  - Bold text"
    echo "  - List items (bulleted and numbered)"
    echo "  - Block quotes"
    echo "  - Code blocks and inline code"
    echo "  - Basic text styling"
}

# Main function
main() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        return 0
    fi

    local file="$1"
    simple_render_markdown "$file"
}

# Execute main function with all arguments
main "$@"
