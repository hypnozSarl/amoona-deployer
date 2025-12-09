# Guide Kubernetes - Amoona Infrastructure

## Table des matières

1. [Architecture Globale](#architecture-globale)
2. [Structure du Repository](#structure-du-repository)
3. [Concepts Kubernetes Essentiels](#concepts-kubernetes-essentiels)
4. [Configuration des Applications](#configuration-des-applications)
5. [Déploiement avec Kustomize](#déploiement-avec-kustomize)
6. [Gestion des Environnements](#gestion-des-environnements)
7. [Commandes Utiles](#commandes-utiles)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Globale

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLUSTER KUBERNETES                          │
│                         IP: 195.35.2.238                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    ┌─────────────────────────────────────────┐    │
│  │   TRAEFIK   │───▶│              INGRESS                     │    │
│  │  (Reverse   │    │  app.amoona.tech → amoona-front         │    │
│  │   Proxy)    │    │  api.amoona.tech → amoona-api           │    │
│  └─────────────┘    └─────────────────────────────────────────┘    │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      NAMESPACES                              │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │   │
│  │  │ amoona-dev  │  │ amoona-prod │  │ monitoring/argocd   │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    SERVICES (par namespace)                  │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │   │
│  │  │ amoona-front │  │  amoona-api  │  │    PostgreSQL    │   │   │
│  │  │   (Nginx)    │  │  (Spring)    │  │                  │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Structure du Repository

```
amoona-deployer/
├── k8s/
│   ├── base/                    # Ressources de base (partagées)
│   │   ├── apps/                # Applications métier
│   │   │   ├── amoona-front/    # Frontend Angular
│   │   │   │   ├── deployment.yaml
│   │   │   │   ├── service.yaml
│   │   │   │   ├── configmap.yaml
│   │   │   │   ├── hpa.yaml
│   │   │   │   └── kustomization.yaml
│   │   │   └── amoona-api/      # Backend Spring Boot
│   │   ├── infra/               # Infrastructure (DB, cache, etc.)
│   │   ├── argocd/              # Configuration ArgoCD
│   │   ├── cert-manager/        # Gestion certificats TLS
│   │   ├── ingress/             # Configuration Traefik
│   │   └── monitoring/          # Prometheus, Grafana
│   │
│   ├── overlays/                # Configurations par environnement
│   │   ├── dev/
│   │   │   ├── apps/
│   │   │   │   └── amoona-front/
│   │   │   │       ├── ingress.yaml
│   │   │   │       ├── replicas-patch.yaml
│   │   │   │       └── kustomization.yaml
│   │   │   └── kustomization.yaml
│   │   └── prod/
│   │       ├── apps/
│   │       │   └── amoona-front/
│   │       └── kustomization.yaml
│   │
│   └── templates/               # Templates réutilisables
│
├── scripts/                     # Scripts d'automatisation
├── docs/                        # Documentation
└── .github/workflows/           # CI/CD GitHub Actions
```

---

## Concepts Kubernetes Essentiels

### Pod
Plus petite unité déployable. Contient un ou plusieurs conteneurs.

```yaml
# Exemple simplifié - un pod est généralement créé via un Deployment
spec:
  containers:
    - name: app
      image: nginx:latest
      ports:
        - containerPort: 80
```

### Deployment
Gère le déploiement et la mise à l'échelle des pods.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: amoona-front
spec:
  replicas: 2                    # Nombre d'instances
  selector:
    matchLabels:
      app: amoona-front
  strategy:
    type: RollingUpdate          # Mise à jour sans interruption
    rollingUpdate:
      maxSurge: 1                # Max pods en plus pendant update
      maxUnavailable: 0          # Pas de downtime
  template:
    spec:
      containers:
        - name: amoona-front
          image: ghcr.io/org/app:latest
          resources:
            requests:            # Ressources garanties
              memory: "256Mi"
              cpu: "100m"
            limits:              # Limites maximales
              memory: "512Mi"
              cpu: "500m"
```

### Service
Expose les pods en interne ou externe.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: amoona-front
spec:
  type: ClusterIP               # Accessible uniquement dans le cluster
  ports:
    - port: 80                  # Port du service
      targetPort: 80            # Port du conteneur
  selector:
    app: amoona-front           # Sélectionne les pods avec ce label
```

**Types de Service :**
| Type | Description |
|------|-------------|
| `ClusterIP` | Accessible uniquement dans le cluster (défaut) |
| `NodePort` | Expose sur un port de chaque node |
| `LoadBalancer` | Crée un load balancer externe |

### Ingress
Route le trafic HTTP/HTTPS vers les services.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: amoona-front
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - app.amoona.tech
      secretName: amoona-front-tls
  rules:
    - host: app.amoona.tech
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: amoona-front
                port:
                  number: 80
```

### ConfigMap
Stocke la configuration non-sensible.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    worker_processes auto;
    events {
      worker_connections 1024;
    }
```

### Secret
Stocke les données sensibles (encodées en base64).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: YWRtaW4=          # echo -n "admin" | base64
  password: cGFzc3dvcmQ=      # echo -n "password" | base64
```

### HPA (Horizontal Pod Autoscaler)
Ajuste automatiquement le nombre de pods.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: amoona-front
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: amoona-front
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

---

## Configuration des Applications

### Probes (Sondes de santé)

```yaml
spec:
  containers:
    - name: app
      # Vérifie si le pod est prêt à recevoir du trafic
      readinessProbe:
        httpGet:
          path: /ready
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 10

      # Vérifie si le pod est vivant (redémarre si échec)
      livenessProbe:
        httpGet:
          path: /live
          port: 80
        initialDelaySeconds: 10
        periodSeconds: 30

      # Vérifie si l'app a démarré (K8s 1.20+)
      startupProbe:
        httpGet:
          path: /health
          port: 80
        failureThreshold: 30
        periodSeconds: 10
```

### Security Context

```yaml
spec:
  securityContext:
    runAsNonRoot: true         # Interdire root
    runAsUser: 101             # UID spécifique
    runAsGroup: 101
    fsGroup: 101
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

### Volumes

```yaml
spec:
  containers:
    - name: app
      volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: config
          mountPath: /etc/nginx/conf.d
  volumes:
    - name: tmp
      emptyDir: {}             # Volume temporaire
    - name: config
      configMap:
        name: nginx-config     # Depuis ConfigMap
```

---

## Déploiement avec Kustomize

Kustomize permet de personnaliser les manifests sans les modifier directement.

### Structure

```
base/                          # Configuration commune
├── deployment.yaml
├── service.yaml
└── kustomization.yaml

overlays/
├── dev/                       # Surcharges pour dev
│   ├── kustomization.yaml
│   └── replicas-patch.yaml
└── prod/                      # Surcharges pour prod
    ├── kustomization.yaml
    └── replicas-patch.yaml
```

### kustomization.yaml (base)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - hpa.yaml

commonLabels:
  app.kubernetes.io/managed-by: kustomize
```

### kustomization.yaml (overlay)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: amoona-dev

resources:
  - ../../base/apps/amoona-front
  - ingress.yaml

patches:
  - path: replicas-patch.yaml

commonLabels:
  environment: dev

images:
  - name: ghcr.io/org/amoona-front
    newTag: develop
```

### Commandes Kustomize

```bash
# Prévisualiser les manifests générés
kubectl kustomize k8s/overlays/dev

# Appliquer directement
kubectl apply -k k8s/overlays/dev

# Voir les différences avant d'appliquer
kubectl diff -k k8s/overlays/dev
```

---

## Gestion des Environnements

### Environnement DEV

| Paramètre | Valeur |
|-----------|--------|
| Namespace | `amoona-dev` |
| URL | `app.dev.amoona.tech` |
| Replicas | 1-3 |
| Ressources | 256Mi RAM, 100m CPU |

### Environnement PROD

| Paramètre | Valeur |
|-----------|--------|
| Namespace | `amoona-prod` |
| URL | `app.amoona.tech` |
| Replicas | 2-10 |
| Ressources | 512Mi-1Gi RAM, 250m-1000m CPU |

### Créer les namespaces

```bash
kubectl create namespace amoona-dev
kubectl create namespace amoona-prod
```

---

## Commandes Utiles

### Gestion des pods

```bash
# Lister les pods
kubectl get pods -n amoona-dev
kubectl get pods -n amoona-dev -o wide        # Avec plus de détails
kubectl get pods -l app=amoona-front          # Par label

# Voir les logs
kubectl logs -n amoona-dev deployment/amoona-front
kubectl logs -n amoona-dev -l app=amoona-front --tail=100
kubectl logs -n amoona-dev pod/amoona-front-xxx -f    # Follow

# Exécuter une commande dans un pod
kubectl exec -n amoona-dev -it deployment/amoona-front -- /bin/sh
kubectl exec -n amoona-dev -it deployment/amoona-front -- curl localhost/health

# Décrire un pod (debug)
kubectl describe pod -n amoona-dev amoona-front-xxx
```

### Gestion des déploiements

```bash
# Status du déploiement
kubectl rollout status deployment/amoona-front -n amoona-dev

# Historique des révisions
kubectl rollout history deployment/amoona-front -n amoona-dev

# Rollback
kubectl rollout undo deployment/amoona-front -n amoona-dev
kubectl rollout undo deployment/amoona-front -n amoona-dev --to-revision=2

# Redémarrer un déploiement
kubectl rollout restart deployment/amoona-front -n amoona-dev

# Scaler manuellement
kubectl scale deployment/amoona-front -n amoona-dev --replicas=3
```

### Gestion des services et ingress

```bash
# Lister les services
kubectl get svc -n amoona-dev

# Lister les ingress
kubectl get ingress -n amoona-dev

# Vérifier les certificats TLS
kubectl get certificates -n amoona-dev
kubectl describe certificate amoona-front-tls -n amoona-dev
```

### Debug réseau

```bash
# Port-forward pour test local
kubectl port-forward -n amoona-dev svc/amoona-front 8080:80

# Tester la connectivité
kubectl run -it --rm debug --image=curlimages/curl -- curl http://amoona-front.amoona-dev.svc.cluster.local/health
```

### Ressources et métriques

```bash
# Utilisation des ressources
kubectl top pods -n amoona-dev
kubectl top nodes

# État du HPA
kubectl get hpa -n amoona-dev
kubectl describe hpa amoona-front -n amoona-dev
```

---

## Troubleshooting

### Pod en CrashLoopBackOff

```bash
# 1. Voir les logs du pod
kubectl logs -n amoona-dev pod/amoona-front-xxx --previous

# 2. Décrire le pod pour voir les événements
kubectl describe pod -n amoona-dev amoona-front-xxx

# Causes fréquentes :
# - Erreur dans la commande de démarrage
# - Probe qui échoue
# - Permissions insuffisantes
# - Image introuvable
```

### Pod en Pending

```bash
# Vérifier les événements
kubectl describe pod -n amoona-dev amoona-front-xxx

# Causes fréquentes :
# - Ressources insuffisantes sur le cluster
# - PersistentVolume non disponible
# - Node selector qui ne match pas
```

### Pod en ImagePullBackOff

```bash
# Vérifier les événements
kubectl describe pod -n amoona-dev amoona-front-xxx

# Causes fréquentes :
# - Image inexistante ou tag incorrect
# - Registry privé sans credentials
# - Problème réseau vers le registry

# Vérifier les secrets pour le registry
kubectl get secrets -n amoona-dev
```

### Service inaccessible

```bash
# 1. Vérifier que les pods sont Running
kubectl get pods -n amoona-dev -l app=amoona-front

# 2. Vérifier les endpoints du service
kubectl get endpoints -n amoona-dev amoona-front

# 3. Tester depuis un autre pod
kubectl run -it --rm debug --image=curlimages/curl -- curl http://amoona-front.amoona-dev:80/health

# 4. Vérifier les labels (selector du service doit matcher les pods)
kubectl get pods -n amoona-dev --show-labels
```

### Ingress ne fonctionne pas

```bash
# 1. Vérifier l'ingress
kubectl describe ingress -n amoona-dev amoona-front

# 2. Vérifier le certificat TLS
kubectl describe certificate -n amoona-dev amoona-front-tls

# 3. Vérifier les logs de Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# 4. Vérifier la résolution DNS
nslookup app.dev.amoona.tech
```

---

## Références

- [Documentation Kubernetes](https://kubernetes.io/docs/)
- [Kustomize](https://kustomize.io/)
- [Traefik Ingress](https://doc.traefik.io/traefik/providers/kubernetes-ingress/)
- [cert-manager](https://cert-manager.io/docs/)
- [ArgoCD](https://argo-cd.readthedocs.io/)