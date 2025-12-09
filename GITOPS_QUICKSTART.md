# GitOps Quick Start Guide

Démarrez avec GitOps en 5 minutes!

## Prérequis

- Repository GitHub configuré
- Cluster Kubernetes (K3s) opérationnel
- `kubectl` configuré localement

## 1. Configuration du Secret KUBECONFIG (2 min)

```bash
# Sur votre serveur K3s
cat ~/.kube/config | base64 -w 0
```

Puis sur GitHub:
1. **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret**
3. Nom: `KUBECONFIG`
4. Valeur: le résultat du base64

## 2. Créer un Nouveau Service (2 min)

```bash
# Utiliser le script interactif
./scripts/create-service.sh

# Ou avec des paramètres
./scripts/create-service.sh mon-api deployment amoona-dev nginx:alpine
```

Le script crée automatiquement:
- `k8s/base/apps/mon-api/deployment.yaml`
- `k8s/base/apps/mon-api/service.yaml`
- `k8s/base/apps/mon-api/configmap.yaml`
- `k8s/base/apps/mon-api/kustomization.yaml`

## 3. Déployer (1 min)

```bash
# Commit et push
git add k8s/base/apps/mon-api/
git commit -m "feat: add mon-api service"
git push origin main
```

**C'est tout!** GitHub Actions:
1. Valide les manifests
2. Déploie sur le cluster
3. Vérifie la santé du service

## 4. Vérifier le Déploiement

```bash
# Voir les pods
kubectl get pods -n amoona-dev

# Voir les logs
kubectl logs -l app=mon-api -n amoona-dev

# Voir le statut du déploiement
kubectl rollout status deployment/mon-api -n amoona-dev
```

## 5. Rollback si Problème

**Option 1: Via GitHub Actions**
- Actions → Rollback Deployment → Run workflow

**Option 2: Via kubectl**
```bash
kubectl rollout undo deployment/mon-api -n amoona-dev
```

**Option 3: Via Git**
```bash
git revert HEAD
git push origin main
```

---

## Workflows Disponibles

| Workflow | Déclencheur | Description |
|----------|-------------|-------------|
| `deploy.yml` | Push main/develop | Déploiement automatique |
| `auto-deploy-new-services.yml` | Nouveau service dans apps/ | Détection et déploiement |
| `rollback.yml` | Manuel | Rollback des déploiements |
| `validate.yml` | PR / Push | Validation des manifests |
| `security.yml` | PR / Push | Scan de sécurité |
| `release.yml` | Tag | Création de release |

---

## Environnements

| Branche | Environnement | Namespace | Domaines |
|---------|---------------|-----------|----------|
| `main` | Production | `amoona-prod` | `*.amoona.tech` |
| `develop` | Développement | `amoona-dev` | `*.dev.amoona.tech` |

---

## Commandes Utiles

```bash
# Générer les manifests localement
./scripts/generate-k8s-configs.sh -a

# Tester tous les services
./scripts/test-all-services.sh

# Déployer manuellement
./scripts/deploy-all.sh dev

# Créer un nouveau service
./scripts/create-service.sh
```

---

## Structure du Projet

```
k8s/
├── base/                    # Configurations de base
│   ├── apps/               # Applications (nouveaux services ici)
│   ├── infra/              # Infrastructure (postgres, redis, minio, elasticsearch)
│   ├── monitoring/         # Monitoring (prometheus, grafana)
│   └── ingress/            # Configuration Ingress
└── overlays/
    ├── dev/                # Overlay développement (amoona-dev)
    └── prod/               # Overlay production (amoona-prod)
```

---

## Liens Utiles

- [Guide GitOps Complet](docs/gitops-guide.md)
- [Configuration DNS](DNS_CONFIGURATION.md)
- [Troubleshooting](docs/kubernetes-commands-troubleshooting.md)
- [Guide Déploiement](docs/guide-kubernetes-deployment.md)

---

## Support

- **Logs GitHub Actions**: Actions → Workflow → View logs
- **État du cluster**: `kubectl get all -n amoona-dev`
- **Événements**: `kubectl get events -n amoona-dev`
