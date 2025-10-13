#!/bin/bash

# --- Configuration ---
# The file where Gemini's feedback will be saved.
OUTPUT_FILE="gemini_feedback.md"

echo "Checking for unstaged changes..."

# Get all unstaged changes from Git.
GIT_DIFF=$(git diff)

# Check if there are any changes.
if [ -z "$GIT_DIFF" ]; then
  echo "No unstaged changes to review. Exiting."
  exit 0
fi

echo "Found changes. Sending to Gemini for review..."

# Create a prompt for Gemini, including the git diff.
# We pipe the diff to the Gemini CLI's standard input.
# The 'Provide a list of suggestions...' part is a clear instruction for the AI.
# The 'For complex changes, provide the full refactored code' gives it an option for larger edits.
echo "$GIT_DIFF" | gemini -p "---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.
tools: Read, Grep, Glob, Bash
---

You are a senior code reviewer ensuring high standards of code quality and security.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code is simple and readable
- Functions and variables are well-named
- No duplicated code
- Proper error handling
- No exposed secrets or API keys
- Input validation implemented
- Good test coverage
- Performance considerations addressed

Provide feedback organized by priority:
- Critical issues (must fix)
- Warnings (should fix)
- Suggestions (consider improving)

Include specific examples of how to fix issues.
Your entire output should be formatted as markdown.

Here is the diff:
" > "$OUTPUT_FILE"

echo "✅ Gemini feedback saved to $OUTPUT_FILE"

# Check if Claude Code is available and we have feedback to process
if command -v claude &> /dev/null && [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    echo "🤖 Asking Claude Code to review Gemini's feedback and apply improvements..."
    
    # Use Claude Code to read the feedback and apply improvements
    claude --non-interactive << EOF
Please read the Gemini feedback from $OUTPUT_FILE and apply the suggested improvements to the codebase. Focus on:
1. Critical issues that must be fixed immediately
2. Security vulnerabilities 
3. Code quality improvements that can be automated
4. Refactoring suggestions that improve maintainability

After making changes, provide a brief summary of what was improved.
EOF
    
    echo "✅ Claude Code has processed the feedback and applied improvements"
else
    echo "ℹ️  Claude Code not available or no feedback to process. You can manually review $OUTPUT_FILE"
fi