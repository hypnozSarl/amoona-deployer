# Configuration DNS - amoona.tech

Guide de configuration DNS pour le domaine amoona.tech avec le cluster Kubernetes.

## Architecture DNS

```
                         ┌─────────────────────────────────────┐
                         │         DNS Provider                │
                         │      (OVH, Cloudflare, etc.)       │
                         └─────────────────┬───────────────────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
            *.amoona.tech          *.dev.amoona.tech        amoona.tech
                    │                      │                      │
                    └──────────────────────┼──────────────────────┘
                                           │
                                           ▼
                              ┌─────────────────────────┐
                              │    195.35.2.238         │
                              │    Serveur K3s          │
                              │    (Traefik Ingress)    │
                              └─────────────────────────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
            ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
            │   amoona-prod │    │   amoona-dev  │    │   monitoring  │
            │   Namespace   │    │   Namespace   │    │   Namespace   │
            └───────────────┘    └───────────────┘    └───────────────┘
```

## Enregistrements DNS Requis

### Production (*.amoona.tech)

| Type | Nom | Valeur | TTL |
|------|-----|--------|-----|
| A | `@` | `195.35.2.238` | 3600 |
| A | `*` | `195.35.2.238` | 3600 |
| A | `grafana` | `195.35.2.238` | 3600 |
| A | `prometheus` | `195.35.2.238` | 3600 |
| A | `minio` | `195.35.2.238` | 3600 |
| A | `s3` | `195.35.2.238` | 3600 |
| A | `elasticsearch` | `195.35.2.238` | 3600 |

### Développement (*.dev.amoona.tech)

| Type | Nom | Valeur | TTL |
|------|-----|--------|-----|
| A | `*.dev` | `195.35.2.238` | 3600 |
| A | `grafana.dev` | `195.35.2.238` | 3600 |
| A | `prometheus.dev` | `195.35.2.238` | 3600 |
| A | `minio.dev` | `195.35.2.238` | 3600 |
| A | `s3.dev` | `195.35.2.238` | 3600 |
| A | `elasticsearch.dev` | `195.35.2.238` | 3600 |

## Configuration par Provider

### OVH

1. Connectez-vous à l'espace client OVH
2. Allez dans **Web Cloud** → **Domaines** → **amoona.tech**
3. Cliquez sur l'onglet **Zone DNS**
4. Ajoutez les enregistrements:

```
# Production
@              IN A     195.35.2.238
*              IN A     195.35.2.238

# Développement
*.dev          IN A     195.35.2.238
```

### Cloudflare

1. Connectez-vous à Cloudflare
2. Sélectionnez le domaine **amoona.tech**
3. Allez dans **DNS** → **Records**
4. Ajoutez:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `@` | `195.35.2.238` | DNS only |
| A | `*` | `195.35.2.238` | DNS only |
| A | `*.dev` | `195.35.2.238` | DNS only |

> **Note**: Désactivez le proxy Cloudflare (orange cloud → grey) pour les wildcards si vous utilisez cert-manager.

### Gandi

1. Connectez-vous à Gandi
2. Allez dans **Domaines** → **amoona.tech** → **Enregistrements DNS**
3. Ajoutez les enregistrements A

### AWS Route 53

```bash
# Via AWS CLI
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.amoona.tech",
        "Type": "A",
        "TTL": 3600,
        "ResourceRecords": [{"Value": "195.35.2.238"}]
      }
    }]
  }'
```

## Services et URLs

### Production (amoona-prod)

| Service | URL | Port Interne |
|---------|-----|--------------|
| Grafana | https://grafana.amoona.tech | 3000 |
| Prometheus | https://prometheus.amoona.tech | 9090 |
| MinIO Console | https://minio.amoona.tech | 9001 |
| MinIO S3 API | https://s3.amoona.tech | 9000 |
| Elasticsearch | https://elasticsearch.amoona.tech | 9200 |

### Développement (amoona-dev)

| Service | URL | Port Interne |
|---------|-----|--------------|
| Grafana | https://grafana.dev.amoona.tech | 3000 |
| Prometheus | https://prometheus.dev.amoona.tech | 9090 |
| MinIO Console | https://minio.dev.amoona.tech | 9001 |
| MinIO S3 API | https://s3.dev.amoona.tech | 9000 |
| Elasticsearch | https://elasticsearch.dev.amoona.tech | 9200 |

## Configuration SSL/TLS

### Avec cert-manager (Recommandé)

Les certificats SSL sont automatiquement gérés par cert-manager avec Let's Encrypt.

1. **Installer cert-manager** (si pas déjà fait):
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

2. **Créer le ClusterIssuer**:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@amoona.tech
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: traefik
```

3. **Appliquer**:
```bash
kubectl apply -f cluster-issuer.yaml
```

Les Ingress en production utilisent automatiquement cert-manager via l'annotation:
```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```

### Sans cert-manager (Manuel)

Si vous préférez gérer les certificats manuellement:

1. Générer un certificat wildcard (ex: via Let's Encrypt certbot)
2. Créer le secret TLS:
```bash
kubectl create secret tls amoona-tls \
  --cert=fullchain.pem \
  --key=privkey.pem \
  -n amoona-prod
```

## Vérification

### Vérifier la propagation DNS

```bash
# Vérifier les enregistrements A
dig +short grafana.amoona.tech
dig +short grafana.dev.amoona.tech

# Vérifier avec nslookup
nslookup grafana.amoona.tech

# Vérifier la propagation mondiale
# https://www.whatsmydns.net/#A/grafana.amoona.tech
```

### Vérifier l'Ingress

```bash
# Voir tous les Ingress
kubectl get ingress -A

# Détails de l'Ingress prod
kubectl describe ingress amoona-ingress -n amoona-prod

# Vérifier les certificats
kubectl get certificates -A
```

### Tester les URLs

```bash
# Test HTTP (dev)
curl -I http://grafana.dev.amoona.tech

# Test HTTPS (prod)
curl -I https://grafana.amoona.tech

# Vérifier le certificat SSL
openssl s_client -connect grafana.amoona.tech:443 -servername grafana.amoona.tech
```

## Dépannage

### DNS ne résout pas

1. Vérifier que les enregistrements sont bien créés chez le provider
2. Attendre la propagation (jusqu'à 48h, généralement quelques minutes)
3. Vider le cache DNS local:
```bash
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

### Certificat SSL invalide

1. Vérifier que cert-manager fonctionne:
```bash
kubectl get pods -n cert-manager
kubectl logs -n cert-manager -l app=cert-manager
```

2. Vérifier les challenges ACME:
```bash
kubectl get challenges -A
kubectl describe challenge <name> -n <namespace>
```

3. Vérifier que le port 80 est accessible (pour HTTP-01 challenge)

### 502 Bad Gateway

1. Vérifier que le service existe:
```bash
kubectl get svc -n amoona-prod
```

2. Vérifier que les pods sont running:
```bash
kubectl get pods -n amoona-prod
```

3. Vérifier les logs de Traefik:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

## Ajouter un Nouveau Sous-domaine

1. **Ajouter l'enregistrement DNS** chez votre provider

2. **Mettre à jour l'Ingress** dans `k8s/overlays/prod/ingress-patch.yaml`:
```yaml
# Ajouter sous spec.tls[0].hosts:
- mon-service.amoona.tech

# Ajouter sous spec.rules:
- host: mon-service.amoona.tech
  http:
    paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mon-service
            port:
              number: 8080
```

3. **Commit et push** - Le déploiement est automatique

## Ressources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [DNS Propagation Checker](https://www.whatsmydns.net/)
