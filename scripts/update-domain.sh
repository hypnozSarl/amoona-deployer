#!/bin/bash

#===============================================================================
# update-domain.sh - Met à jour le domaine dans tous les fichiers de configuration
# Usage: ./scripts/update-domain.sh [old-domain] [new-domain]
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║       🌐 Amoona Domain Updater                                ║"
    echo "║                                                               ║"
    echo "║  Met à jour le domaine dans toute la configuration K8s       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Show usage
usage() {
    echo "Usage: $0 [old-domain] [new-domain]"
    echo ""
    echo "Arguments:"
    echo "  old-domain    Domaine actuel (ex: amoona.tech)"
    echo "  new-domain    Nouveau domaine (ex: example.com)"
    echo ""
    echo "Options:"
    echo "  -h, --help    Afficher cette aide"
    echo "  -d, --dry-run Afficher les changements sans les appliquer"
    echo ""
    echo "Examples:"
    echo "  $0 amoona.tech example.com"
    echo "  $0 --dry-run amoona.tech example.com"
}

# Find files containing the domain
find_domain_files() {
    local domain="$1"
    local escaped_domain=$(echo "$domain" | sed 's/\./\\./g')

    find "$PROJECT_ROOT" \
        -type f \
        \( -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.sh" \) \
        ! -path "*/.git/*" \
        ! -path "*/node_modules/*" \
        -exec grep -l "$domain" {} \; 2>/dev/null
}

# Count occurrences
count_occurrences() {
    local domain="$1"
    local file="$2"
    grep -c "$domain" "$file" 2>/dev/null || echo "0"
}

# Preview changes
preview_changes() {
    local old_domain="$1"
    local new_domain="$2"

    echo ""
    print_info "Aperçu des changements:"
    echo ""

    local files=$(find_domain_files "$old_domain")
    local total_files=0
    local total_occurrences=0

    if [ -z "$files" ]; then
        print_warning "Aucun fichier ne contient le domaine '$old_domain'"
        return 1
    fi

    echo "Fichiers à modifier:"
    echo ""

    while IFS= read -r file; do
        if [ -n "$file" ]; then
            local rel_path="${file#$PROJECT_ROOT/}"
            local count=$(count_occurrences "$old_domain" "$file")
            echo "  📄 $rel_path ($count occurrences)"
            total_files=$((total_files + 1))
            total_occurrences=$((total_occurrences + count))
        fi
    done <<< "$files"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: $total_files fichiers, $total_occurrences occurrences"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    return 0
}

# Apply changes
apply_changes() {
    local old_domain="$1"
    local new_domain="$2"

    local files=$(find_domain_files "$old_domain")
    local modified_count=0

    while IFS= read -r file; do
        if [ -n "$file" ]; then
            local rel_path="${file#$PROJECT_ROOT/}"

            # Create backup
            cp "$file" "${file}.bak"

            # Replace domain
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s/$old_domain/$new_domain/g" "$file"
            else
                # Linux
                sed -i "s/$old_domain/$new_domain/g" "$file"
            fi

            # Verify change was made
            if ! diff -q "$file" "${file}.bak" > /dev/null 2>&1; then
                print_success "Modifié: $rel_path"
                modified_count=$((modified_count + 1))
            fi

            # Remove backup
            rm "${file}.bak"
        fi
    done <<< "$files"

    return $modified_count
}

# Main function
main() {
    local dry_run=false
    local old_domain=""
    local new_domain=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            *)
                if [ -z "$old_domain" ]; then
                    old_domain="$1"
                elif [ -z "$new_domain" ]; then
                    new_domain="$1"
                fi
                shift
                ;;
        esac
    done

    print_header

    # Interactive mode if arguments not provided
    if [ -z "$old_domain" ]; then
        read -p "Domaine actuel [amoona.tech]: " old_domain
        old_domain="${old_domain:-amoona.tech}"
    fi

    if [ -z "$new_domain" ]; then
        read -p "Nouveau domaine: " new_domain
    fi

    # Validate inputs
    if [ -z "$new_domain" ]; then
        print_error "Le nouveau domaine est requis"
        exit 1
    fi

    if [ "$old_domain" = "$new_domain" ]; then
        print_error "Les domaines sont identiques"
        exit 1
    fi

    # Validate domain format
    if [[ ! "$new_domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
        print_warning "Le format du domaine '$new_domain' semble invalide"
        read -p "Continuer quand même? (y/n) [n]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    echo ""
    print_info "Domaine actuel: $old_domain"
    print_info "Nouveau domaine: $new_domain"
    echo ""

    # Preview changes
    if ! preview_changes "$old_domain" "$new_domain"; then
        exit 1
    fi

    # Dry run mode
    if [ "$dry_run" = true ]; then
        print_info "Mode dry-run: aucune modification appliquée"
        echo ""
        echo "Pour appliquer les changements, exécutez:"
        echo "  $0 $old_domain $new_domain"
        exit 0
    fi

    # Confirm
    read -p "Appliquer ces changements? (y/n) [n]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Annulé"
        exit 0
    fi

    echo ""
    print_info "Application des changements..."
    echo ""

    # Apply changes
    apply_changes "$old_domain" "$new_domain"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Domaine mis à jour: $old_domain → $new_domain"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Next steps
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo ""
    echo "  1. Vérifier les modifications:"
    echo "     git diff"
    echo ""
    echo "  2. Mettre à jour les enregistrements DNS chez votre registrar"
    echo "     Pointer *.${new_domain} vers votre serveur"
    echo ""
    echo "  3. Commit et push:"
    echo "     git add ."
    echo "     git commit -m \"chore: update domain from $old_domain to $new_domain\""
    echo "     git push origin main"
    echo ""
    echo "  4. Mettre à jour les certificats SSL (si nécessaire)"
    echo ""
}

# Run main
main "$@"
