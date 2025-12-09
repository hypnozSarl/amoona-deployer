#!/bin/bash

#===============================================================================
# generate-k8s-configs.sh - Génère les configurations Kubernetes complètes
# Usage: ./scripts/generate-k8s-configs.sh [environment] [output-dir]
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

# Default values
DEFAULT_ENV="dev"
DEFAULT_OUTPUT_DIR="generated"

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║       🔧 Amoona Kubernetes Config Generator                   ║"
    echo "║                                                               ║"
    echo "║  Génère les manifests Kubernetes via Kustomize               ║"
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

# Check if kustomize is installed
check_kustomize() {
    if ! command -v kustomize &> /dev/null; then
        if ! command -v kubectl &> /dev/null; then
            print_error "kustomize ou kubectl est requis mais non installé"
            echo ""
            echo "Installation de kustomize:"
            echo "  curl -s \"https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh\" | bash"
            exit 1
        else
            print_info "Utilisation de 'kubectl kustomize' au lieu de 'kustomize'"
            KUSTOMIZE_CMD="kubectl kustomize"
        fi
    else
        KUSTOMIZE_CMD="kustomize build"
    fi
}

# Generate configs for an environment
generate_for_env() {
    local env="$1"
    local output_dir="$2"
    local overlay_dir="${PROJECT_ROOT}/k8s/overlays/${env}"

    if [ ! -d "$overlay_dir" ]; then
        print_error "L'environnement '${env}' n'existe pas: ${overlay_dir}"
        return 1
    fi

    local output_file="${output_dir}/${env}-manifests.yaml"

    print_info "Génération des manifests pour l'environnement '${env}'..."

    # Create output directory if needed
    mkdir -p "$output_dir"

    # Generate manifests
    if $KUSTOMIZE_CMD "$overlay_dir" > "$output_file" 2>&1; then
        print_success "Manifests générés: ${output_file}"

        # Count resources
        local resource_count=$(grep -c "^kind:" "$output_file" 2>/dev/null || echo "0")
        print_info "Nombre de ressources: ${resource_count}"

        # List resource types
        echo ""
        echo "Types de ressources:"
        grep "^kind:" "$output_file" | sort | uniq -c | while read count kind; do
            echo "  - ${kind#kind: }: ${count}"
        done
    else
        print_error "Erreur lors de la génération des manifests"
        cat "$output_file"
        return 1
    fi
}

# Validate generated manifests
validate_manifests() {
    local manifest_file="$1"

    print_info "Validation des manifests..."

    # Check if kubeconform is available
    if command -v kubeconform &> /dev/null; then
        if kubeconform -strict -summary "$manifest_file"; then
            print_success "Validation kubeconform réussie"
        else
            print_warning "Certaines ressources n'ont pas passé la validation"
        fi
    # Check if kubeval is available
    elif command -v kubeval &> /dev/null; then
        if kubeval --strict "$manifest_file"; then
            print_success "Validation kubeval réussie"
        else
            print_warning "Certaines ressources n'ont pas passé la validation"
        fi
    else
        print_warning "kubeconform ou kubeval non installé - validation ignorée"
        echo "  Installation: https://github.com/yannh/kubeconform"
    fi
}

# Generate diff between environments
generate_diff() {
    local output_dir="$1"
    local dev_file="${output_dir}/dev-manifests.yaml"
    local prod_file="${output_dir}/prod-manifests.yaml"

    if [ -f "$dev_file" ] && [ -f "$prod_file" ]; then
        print_info "Génération du diff entre dev et prod..."

        local diff_file="${output_dir}/dev-vs-prod.diff"
        diff -u "$dev_file" "$prod_file" > "$diff_file" 2>&1 || true

        if [ -s "$diff_file" ]; then
            print_success "Diff généré: ${diff_file}"
            echo ""
            echo "Résumé des différences:"
            echo "  - Lignes ajoutées (prod): $(grep -c "^+" "$diff_file" 2>/dev/null || echo 0)"
            echo "  - Lignes supprimées (prod): $(grep -c "^-" "$diff_file" 2>/dev/null || echo 0)"
        else
            print_info "Aucune différence entre dev et prod"
        fi
    fi
}

# Generate resource summary
generate_summary() {
    local output_dir="$1"
    local summary_file="${output_dir}/SUMMARY.md"

    print_info "Génération du résumé..."

    cat > "$summary_file" << EOF
# Kubernetes Manifests Summary

Generated: $(date)

## Environments

EOF

    for env in dev prod; do
        local manifest_file="${output_dir}/${env}-manifests.yaml"
        if [ -f "$manifest_file" ]; then
            echo "### ${env^} Environment" >> "$summary_file"
            echo "" >> "$summary_file"
            echo "| Resource Type | Count |" >> "$summary_file"
            echo "|--------------|-------|" >> "$summary_file"
            grep "^kind:" "$manifest_file" | sort | uniq -c | while read count kind; do
                echo "| ${kind#kind: } | ${count} |" >> "$summary_file"
            done
            echo "" >> "$summary_file"

            # Add namespace info
            local namespace=$(grep "namespace:" "$manifest_file" | head -1 | awk '{print $2}')
            echo "**Namespace:** \`${namespace}\`" >> "$summary_file"
            echo "" >> "$summary_file"
        fi
    done

    cat >> "$summary_file" << EOF
## Usage

Apply to dev environment:
\`\`\`bash
kubectl apply -f ${output_dir}/dev-manifests.yaml
\`\`\`

Apply to prod environment:
\`\`\`bash
kubectl apply -f ${output_dir}/prod-manifests.yaml
\`\`\`

## Dry Run

\`\`\`bash
kubectl apply --dry-run=client -f ${output_dir}/dev-manifests.yaml
\`\`\`
EOF

    print_success "Résumé généré: ${summary_file}"
}

# Show usage
usage() {
    echo "Usage: $0 [options] [environment]"
    echo ""
    echo "Options:"
    echo "  -o, --output DIR    Répertoire de sortie (default: generated)"
    echo "  -a, --all           Générer pour tous les environnements"
    echo "  -v, --validate      Valider les manifests générés"
    echo "  -d, --diff          Générer le diff entre environnements"
    echo "  -h, --help          Afficher cette aide"
    echo ""
    echo "Environments:"
    echo "  dev                 Environnement de développement (amoona-dev)"
    echo "  prod                Environnement de production (amoona-prod)"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Générer pour dev"
    echo "  $0 -a                     # Générer pour tous"
    echo "  $0 -a -v                  # Générer et valider"
    echo "  $0 prod -o /tmp/k8s      # Générer prod dans /tmp/k8s"
}

# Main function
main() {
    local environment=""
    local output_dir="${PROJECT_ROOT}/${DEFAULT_OUTPUT_DIR}"
    local generate_all=false
    local validate=false
    local generate_diff_flag=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -a|--all)
                generate_all=true
                shift
                ;;
            -v|--validate)
                validate=true
                shift
                ;;
            -d|--diff)
                generate_diff_flag=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            dev|prod)
                environment="$1"
                shift
                ;;
            *)
                print_error "Option inconnue: $1"
                usage
                exit 1
                ;;
        esac
    done

    print_header

    # Check kustomize
    check_kustomize

    # Determine what to generate
    if [ "$generate_all" = true ]; then
        environments=("dev" "prod")
    elif [ -n "$environment" ]; then
        environments=("$environment")
    else
        environments=("$DEFAULT_ENV")
    fi

    # Create output directory
    mkdir -p "$output_dir"

    echo ""
    print_info "Répertoire de sortie: ${output_dir}"
    echo ""

    # Generate for each environment
    for env in "${environments[@]}"; do
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  Environnement: ${env}${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        if generate_for_env "$env" "$output_dir"; then
            if [ "$validate" = true ]; then
                echo ""
                validate_manifests "${output_dir}/${env}-manifests.yaml"
            fi
        fi
    done

    # Generate diff if requested
    if [ "$generate_diff_flag" = true ] && [ ${#environments[@]} -gt 1 ]; then
        echo ""
        generate_diff "$output_dir"
    fi

    # Generate summary
    echo ""
    generate_summary "$output_dir"

    # Final summary
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Génération terminée!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Fichiers générés:"
    ls -la "$output_dir"/*.yaml 2>/dev/null || echo "  Aucun fichier YAML"
    ls -la "$output_dir"/*.md 2>/dev/null || echo ""
    echo ""
    echo "Pour appliquer les manifests:"
    for env in "${environments[@]}"; do
        echo "  kubectl apply -f ${output_dir}/${env}-manifests.yaml"
    done
    echo ""
}

# Run main
main "$@"
