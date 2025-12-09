# Guide GitOps - Amoona Kubernetes Deployment

Ce guide décrit la configuration GitOps complète pour le déploiement automatisé de l'infrastructure Kubernetes Amoona.

## Table des Matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture GitOps](#architecture-gitops)
- [Workflows GitHub Actions](#workflows-github-actions)
- [Configuration des Secrets](#configuration-des-secrets)
- [Utilisation](#utilisation)
- [Dépannage](#dépannage)

## Vue d'ensemble

Le projet utilise une approche GitOps où :
- **Git est la source de vérité** pour toute la configuration Kubernetes
- **Les déploiements sont automatiques** lors des push sur les branches principales
- **Les rollbacks sont simples** via l'historique Git ou les workflows dédiés

### Flux de Travail

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Code      │ --> │   GitHub    │ --> │   GitHub    │ --> │ Kubernetes  │
│   Push      │     │   Actions   │     │   Validate  │     │   Deploy    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                           │                   │
                           v                   v
                    ┌─────────────┐     ┌─────────────┐
                    │  Security   │     │   Health    │
                    │    Scan     │     │   Check     │
                    └─────────────┘     └─────────────┘
```

## Architecture GitOps

### Structure des Branches

| Branche | Environnement | Déploiement |
|---------|---------------|-------------|
| `main` | Production | Automatique |
| `develop` | Développement | Automatique |
| `feature/*` | - | PR uniquement |

### Environnements Kubernetes

| Environnement | Namespace | Domaines |
|---------------|-----------|----------|
| Production | `amoona-prod` | `*.amoona.tech` |
| Développement | `amoona-dev` | `*.dev.amoona.tech` |

## Workflows GitHub Actions

### 1. Deploy (`deploy.yml`)

Workflow principal pour le déploiement automatique.

**Déclencheurs :**
- Push sur `main` (→ prod)
- Push sur `develop` (→ dev)
- Pull Request (validation uniquement)
- Manuel via `workflow_dispatch`

**Fonctionnalités :**
- Détection automatique des services modifiés
- Validation des manifests avec kubeconform
- Déploiement avec rollout status
- Health check post-déploiement
- Auto-rollback en cas d'échec

**Utilisation manuelle :**
```bash
gh workflow run deploy.yml \
  -f environment=prod \
  -f dry_run=false
```

### 2. Auto Deploy New Services (`auto-deploy-new-services.yml`)

Détecte et déploie automatiquement les nouveaux services ajoutés dans `k8s/base/apps/`.

**Déclencheurs :**
- Push sur `main`/`develop` avec modifications dans `k8s/base/apps/`
- Manuel avec nom de service spécifique

**Fonctionnalités :**
- Détection des nouveaux répertoires de services
- Validation de la structure du service
- Scan de sécurité avec Checkov
- Déploiement et vérification

**Utilisation manuelle :**
```bash
gh workflow run auto-deploy-new-services.yml \
  -f service_name=my-new-service \
  -f environment=dev
```

### 3. Rollback (`rollback.yml`)

Workflow manuel pour effectuer des rollbacks.

**Types de Rollback :**

| Type | Description |
|------|-------------|
| `specific_service` | Rollback un service spécifique |
| `all_services` | Rollback tous les workloads |
| `git_revision` | Redéployer depuis un commit Git |

**Utilisation :**
```bash
# Rollback d'un service spécifique
gh workflow run rollback.yml \
  -f environment=prod \
  -f rollback_type=specific_service \
  -f service_name=grafana

# Rollback vers un commit Git
gh workflow run rollback.yml \
  -f environment=prod \
  -f rollback_type=git_revision \
  -f git_revision=abc123

# Rollback de tous les services
gh workflow run rollback.yml \
  -f environment=dev \
  -f rollback_type=all_services
```

### 4. Validate (`validate.yml`)

Validation continue des manifests Kubernetes.

**Vérifications :**
- Build Kustomize (dev + prod)
- Lint YAML avec yamllint
- Validation kubeconform
- ShellCheck pour les scripts

### 5. Security (`security.yml`)

Scan de sécurité automatique.

**Outils :**
- **Trivy** : Scan des vulnérabilités
- **Checkov** : Analyse IaC
- **Gitleaks** : Détection de secrets

## Configuration des Secrets

### Secrets GitHub Requis

| Secret | Description | Comment l'obtenir |
|--------|-------------|-------------------|
| `KUBECONFIG` | Configuration kubectl (base64) | `cat ~/.kube/config \| base64` |

### Configuration du Kubeconfig

1. Récupérer le kubeconfig du cluster :
```bash
# Sur le serveur K3s
sudo cat /etc/rancher/k3s/k3s.yaml
```

2. Modifier l'adresse du serveur si nécessaire :
```yaml
clusters:
- cluster:
    server: https://YOUR_SERVER_IP:6443
```

3. Encoder en base64 :
```bash
cat k3s.yaml | base64 -w 0
```

4. Ajouter le secret dans GitHub :
   - Settings → Secrets and variables → Actions
   - New repository secret : `KUBECONFIG`

### Environnements GitHub

Créer les environnements dans GitHub :
1. Settings → Environments
2. Créer `dev` et `prod`
3. Configurer les règles de protection pour `prod` :
   - Required reviewers
   - Wait timer (optionnel)

## Utilisation

### Déploiement Standard

1. **Modifier les manifests** dans `k8s/`
2. **Commit et push** :
```bash
git add k8s/
git commit -m "feat: update grafana configuration"
git push origin develop  # Pour dev
git push origin main     # Pour prod
```
3. **Le workflow se déclenche automatiquement**

### Ajouter un Nouveau Service

1. Créer la structure dans `k8s/base/apps/` :
```
k8s/base/apps/my-service/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
└── configmap.yaml
```

2. Ajouter au fichier `k8s/base/apps/kustomization.yaml` :
```yaml
resources:
  - my-service
```

3. Commit et push - le workflow `auto-deploy-new-services.yml` détectera et déploiera le service.

### Effectuer un Rollback

**Via GitHub UI :**
1. Actions → Rollback Deployment
2. Run workflow
3. Sélectionner les paramètres

**Via CLI :**
```bash
# Voir les workflows disponibles
gh workflow list

# Lancer un rollback
gh workflow run rollback.yml -f environment=prod -f rollback_type=specific_service -f service_name=grafana
```

### Vérifier le Statut

```bash
# Voir les runs récents
gh run list --workflow=deploy.yml

# Voir les détails d'un run
gh run view <run-id>

# Voir les logs
gh run view <run-id> --log
```

## Dépannage

### Le déploiement échoue

1. **Vérifier les logs du workflow** :
```bash
gh run view <run-id> --log-failed
```

2. **Vérifier l'état du cluster** :
```bash
kubectl get pods -n amoona-<env>
kubectl describe pod <pod-name> -n amoona-<env>
kubectl logs <pod-name> -n amoona-<env>
```

3. **Causes courantes** :
   - KUBECONFIG invalide ou expiré
   - Ressources insuffisantes sur le cluster
   - PVC en attente (StorageClass manquante)

### La validation échoue

1. **kubeconform errors** :
   - Vérifier la syntaxe YAML
   - Vérifier les versions d'API Kubernetes

2. **Kustomize build fails** :
   - Vérifier les chemins dans `kustomization.yaml`
   - Vérifier les patches

### Le rollback ne fonctionne pas

1. **Vérifier l'historique des révisions** :
```bash
kubectl rollout history deployment/<name> -n amoona-<env>
```

2. **Rollback manuel** :
```bash
kubectl rollout undo deployment/<name> -n amoona-<env>
```

## Bonnes Pratiques

### Commits

```bash
# Format recommandé
git commit -m "type(scope): description"

# Exemples
git commit -m "feat(grafana): add new dashboard"
git commit -m "fix(postgres): increase memory limit"
git commit -m "chore(deps): update kustomize version"
```

### Pull Requests

1. Créer une PR vers `develop` ou `main`
2. Attendre la validation automatique
3. Review et merge

### Tags et Releases

```bash
# Créer un tag pour une release
git tag -a v1.2.0 -m "Release 1.2.0"
git push origin v1.2.0
```

## Notifications (Optionnel)

Pour activer les notifications Slack/Discord, ajouter le secret `SLACK_WEBHOOK_URL` et décommenter les sections de notification dans les workflows.

```yaml
# Exemple notification Slack
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"✅ Deployment successful!"}' \
  ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Ressources

- [Kustomize Documentation](https://kustomize.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
