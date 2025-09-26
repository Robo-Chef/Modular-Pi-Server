#!/bin/bash

# Script to fix common markdown issues in the project
# This script should be run from the root of the repository

set -euo pipefail

# Install required tools if not already installed
if ! command -v prettier &> /dev/null; then
    echo "Installing prettier..."
    npm install -g prettier@3.0.0 prettier-plugin-markdown@2.0.0
fi

# Create markdownlint config directory if it doesn't exist
mkdir -p .github/configs

# Create or update markdownlint config
cat > .github/configs/.markdownlint.json << 'EOL'
{
  "default": true,
  "MD013": {
    "line_length": 100,
    "code_blocks": false,
    "tables": false,
    "headers": false
  },
  "MD024": {
    "siblings_only": true
  },
  "MD025": {
    "level": 1,
    "front_matter_title": "^---\\n.*title:.*\\n---\\n"
  },
  "MD030": {
    "ul_single": 1,
    "ul_multi": 1
  },
  "MD033": {
    "allowed_elements": ["img", "br", "hr", "a", "button", "input", "label", "select", "option", "textarea", "details", "summary", "div", "span", "svg", "path"]
  },
  "MD034": {
    "allowed_elements": ["a"]
  },
  "MD036": {
    "punctuation": ",.;:!?"
  },
  "MD040": {
    "allowed_languages": ["bash", "yaml", "json", "dockerfile", "ini", "toml", "sql", "python", "javascript", "typescript", "html", "css", "scss", "xml", "markdown"]
  },
  "MD041": {
    "level": 1,
    "front_matter_title": "^---\\n.*title:.*\\n---\\n"
  }
}
EOL

# Find all markdown files and fix them with prettier
echo "Fixing markdown files..."
find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.github/*" -exec prettier --write --prose-wrap always {} \;

# Fix line endings
echo "Fixing line endings..."
find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.github/*" -exec dos2unix {} \;

echo "Markdown files have been formatted successfully!"
echo "Please review the changes and commit them."
