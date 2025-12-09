#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
REPO_NAME="amoona-deployer"
VISIBILITY="private"
REMOTE_NAME="origin"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            REPO_NAME="$2"
            shift 2
            ;;
        --public)
            VISIBILITY="public"
            shift
            ;;
        --private)
            VISIBILITY="private"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --name NAME     Repository name (default: amoona-deployer)"
            echo "  --public        Create a public repository"
            echo "  --private       Create a private repository (default)"
            echo "  -h, --help      Show this help message"
            echo ""
            echo "Note: This script prepares the repository but does NOT"
            echo "      execute 'gh repo create' or 'git push' automatically."
            echo "      You must run those commands manually after review."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if git is initialized
check_git_init() {
    log_info "Checking git initialization..."

    cd "$PROJECT_ROOT"

    if [[ ! -d ".git" ]]; then
        log_info "Initializing git repository..."
        git init
        log_success "Git repository initialized"
    else
        log_info "Git repository already initialized"
    fi
}

# Create .gitignore if not exists
create_gitignore() {
    GITIGNORE_PATH="$PROJECT_ROOT/.gitignore"

    if [[ -f "$GITIGNORE_PATH" ]]; then
        log_info ".gitignore already exists, skipping..."
        return 0
    fi

    log_info "Creating .gitignore..."

    cat > "$GITIGNORE_PATH" << 'EOF'
# IDE
.idea/
.vscode/
*.iml

# OS
.DS_Store
Thumbs.db

# Secrets (never commit real secrets!)
**/secrets/*.yaml
!**/secrets/*.example.yaml

# Generated manifests
complete-manifest.yaml
*.generated.yaml

# Temporary files
*.tmp
*.bak
*.swp

# Logs
*.log

# Local environment
.env
.env.local
EOF

    log_success ".gitignore created"
}

# Stage all files
stage_files() {
    log_info "Staging files..."

    cd "$PROJECT_ROOT"
    git add -A

    # Show what will be committed
    echo ""
    log_info "Files staged for commit:"
    git status --short
    echo ""
}

# Create initial commit if needed
create_initial_commit() {
    cd "$PROJECT_ROOT"

    # Check if there are staged changes
    if git diff --cached --quiet; then
        log_info "No changes to commit"
        return 0
    fi

    log_info "Creating commit..."
    git commit -m "feat: Initialize Kubernetes Amoona Deployment infrastructure

- Add PostgreSQL 16 StatefulSet with persistent storage
- Add Redis 7 Deployment with custom configuration
- Add MinIO object storage with PVC
- Add Elasticsearch 8 StatefulSet for search/logging
- Add Prometheus monitoring with RBAC and scrape configs
- Add Grafana with datasources and dashboard provisioning
- Configure Kustomize base and overlays for dev/prod
- Add deployment automation scripts"

    log_success "Initial commit created"
}

# Print next steps
print_next_steps() {
    echo ""
    echo "=================================="
    echo "  Repository Setup Complete"
    echo "=================================="
    echo ""
    log_info "To create a GitHub repository and push, run these commands manually:"
    echo ""
    echo "  # Create GitHub repository (requires gh CLI and authentication)"
    echo "  gh repo create $REPO_NAME --$VISIBILITY --source=. --push"
    echo ""
    echo "  # Or manually add remote and push:"
    echo "  git remote add origin git@github.com:YOUR_USERNAME/$REPO_NAME.git"
    echo "  git branch -M main"
    echo "  git push -u origin main"
    echo ""
    log_warning "Remember to update production secrets before deploying!"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=================================="
    echo "  Git Repository Initializer"
    echo "  Repository: $REPO_NAME"
    echo "  Visibility: $VISIBILITY"
    echo "=================================="
    echo ""

    check_git_init
    create_gitignore
    stage_files
    create_initial_commit
    print_next_steps

    log_success "Setup complete!"
}

main
