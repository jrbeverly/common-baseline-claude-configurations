#!/bin/bash
# Apply Claude Bootstrap Recipe
#
# Applies .claude/ and/or .devcontainer/ directories when missing
#
# Args:
#   $1 - Repository owner
#   $2 - Repository name
#   $3 - Clone path
#   $4 - API token
#   $5 - Gitea URL
#
# Exit codes:
#   0 - Success (one or both directories were added)
#   1 - Error (failed to apply bootstrap)
#   2 - Skip (both directories already exist)

set -euo pipefail

REPO_OWNER="$1"
REPO_NAME="$2"
CLONE_PATH="$3"
API_TOKEN="$4"
GITEA_URL="$5"

RECIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_ROOT="$RECIPE_DIR"

echo "Checking repository: ${REPO_OWNER}/${REPO_NAME}"

# Navigate to cloned repository
cd "$CLONE_PATH"

# Check what's missing
CLAUDE_EXISTS=false
DEVCONTAINER_EXISTS=false
CHANGES_MADE=false
APPLIED=()

if [ -d ".claude" ]; then
    CLAUDE_EXISTS=true
fi

if [ -d ".devcontainer" ]; then
    DEVCONTAINER_EXISTS=true
fi

# Idempotency check: skip if both already exist
if [ "$CLAUDE_EXISTS" = true ] && [ "$DEVCONTAINER_EXISTS" = true ]; then
    echo "SKIP: Both .claude/ and .devcontainer/ directories already exist"
    exit 2
fi

# Configure git
git config user.name "Workspace Automation"
git config user.email "automation@workspace"

# Apply .claude/ if missing
if [ "$CLAUDE_EXISTS" = false ]; then
    echo "Applying .claude/ bootstrap..."

    if [ ! -d "$BOOTSTRAP_ROOT/.claude" ]; then
        echo "ERROR: Bootstrap source not found at $BOOTSTRAP_ROOT/.claude"
        exit 1
    fi

    cp -r "$BOOTSTRAP_ROOT/.claude" .claude
    git add .claude/
    APPLIED+=(".claude/")
    CHANGES_MADE=true
fi

# Apply .devcontainer/ if missing
if [ "$DEVCONTAINER_EXISTS" = false ]; then
    echo "Applying .devcontainer/ bootstrap..."

    if [ ! -d "$BOOTSTRAP_ROOT/.devcontainer" ]; then
        echo "ERROR: Bootstrap source not found at $BOOTSTRAP_ROOT/.devcontainer"
        exit 1
    fi

    cp -r "$BOOTSTRAP_ROOT/.devcontainer" .devcontainer
    git add .devcontainer/
    APPLIED+=(".devcontainer/")
    CHANGES_MADE=true
fi

# Only commit and push if changes were made
if [ "$CHANGES_MADE" = false ]; then
    echo "SKIP: No changes to apply"
    exit 2
fi

# Build commit message based on what was applied
COMMIT_MSG="Apply Claude Bootstrap"

if [ "${#APPLIED[@]}" -eq 2 ]; then
    # Both applied
    COMMIT_MSG="${COMMIT_MSG}

Adds complete bootstrap configuration:

.claude/ - AI Assistant Knowledge Base:
- CLAUDE.md: AI assistant context and conventions
- guidelines/: Coding standards and best practices
- preferences/: Technology choices and defaults
- constraints/: Repository structure rules
- rules/: LLM code generation instructions

.devcontainer/ - Development Environment:
- devcontainer.json: Container configuration
- Dockerfile: Base image definition
- features/: Custom devcontainer features
- lifecycle/: Post-create orchestration scripts
- README.md: DevContainer documentation

Applied via workspace automation recipe: claude-bootstrap"

elif [[ " ${APPLIED[@]} " =~ " .claude/ " ]]; then
    # Only .claude/ applied
    COMMIT_MSG="${COMMIT_MSG}

Adds .claude/ directory with:
- CLAUDE.md: AI assistant context and conventions
- guidelines/: Coding standards and best practices
- preferences/: Technology choices and defaults
- constraints/: Repository structure rules
- rules/: LLM code generation instructions

Applied via workspace automation recipe: claude-bootstrap"

else
    # Only .devcontainer/ applied
    COMMIT_MSG="${COMMIT_MSG}

Adds .devcontainer/ directory with:
- devcontainer.json: Container configuration
- Dockerfile: Base image definition
- features/: Custom devcontainer features
- lifecycle/: Post-create orchestration scripts
- README.md: DevContainer documentation

Applied via workspace automation recipe: claude-bootstrap"
fi

# Commit changes
git commit -m "$COMMIT_MSG"

# Push changes
git push origin HEAD

echo "SUCCESS: Applied ${APPLIED[*]} to ${REPO_OWNER}/${REPO_NAME}"
exit 0
