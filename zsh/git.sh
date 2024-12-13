#!/bin/bash

# Get the remote URL of the current repository
remote_url=$(git remote get-url origin)

# Check if the remote URL is valid
if [[ -z "$remote_url" ]]; then
    echo "No remote repository found."
    exit 1
fi

# Convert the remote URL to a web URL
if [[ "$remote_url" == *"git@"* ]]; then
    # For SSH URLs (git@github.com:user/repo.git)
    web_url=${remote_url/git@/https://}
    web_url=${web_url/:/\/}
    web_url=${web_url/.git/}
else
    # For HTTPS URLs (https://github.com/user/repo.git)
    web_url=${remote_url/.git/}
fi

# Open the web URL in the default browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    open "$web_url"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "$web_url"
elif [[ "$OSTYPE" == "cygwin" ]]; then
    start "$web_url"
elif [[ "$OSTYPE" == "msys" ]]; then
    start "$web_url"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

