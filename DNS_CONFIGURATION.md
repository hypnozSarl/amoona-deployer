# Configuration DNS pour amoona.tech

Ce guide vous explique comment configurer les enregistrements DNS pour votre domaine **amoona.tech** afin que tous les sous-domaines pointent vers votre cluster Kubernetes.

---

## Sous-domaines Configurés

### Production (amoona-prod)

| Sous-domaine | Service | Port |
|--------------|---------|------|
| grafana.amoona.tech | Dashboard Grafana | 3000 |
| prometheus.amoona.tech | Métriques Prometheus | 9090 |
| minio.amoona.tech | Console MinIO | 9001 |
| s3.amoona.tech | API S3 MinIO | 9000 |
| elasticsearch.amoona.tech | API Elasticsearch | 9200 |

### Développement (amoona-dev)

| Sous-domaine | Service | Port |
|--------------|---------|------|
| grafana.dev.amoona.tech | Dashboard Grafana | 3000 |
| prometheus.dev.amoona.tech | Métriques Prometheus | 9090 |
| minio.dev.amoona.tech | Console MinIO | 9001 |
| s3.dev.amoona.tech | API S3 MinIO | 9000 |
| elasticsearch.dev.amoona.tech | API Elasticsearch | 9200 |

---

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
                         ┌─────────────────┴─────────────────┐
                         │                                   │
                         ▼                                   ▼
                 ┌───────────────┐                   ┌───────────────┐
                 │  amoona-prod  │                   │  amoona-dev   │
                 │   Namespace   │                   │   Namespace   │
                 └───────────────┘                   └───────────────┘
```

---

## Option 1: Enregistrements DNS Individuels (Recommandé)

### Chez votre Registrar (OVH, Gandi, Cloudflare, etc.)

Ajoutez ces enregistrements DNS de type **A** pointant vers `195.35.2.238`:

#### Production

```
Type  | Nom           | Valeur         | TTL
------|---------------|----------------|-----
A     | grafana       | 195.35.2.238   | 3600
A     | prometheus    | 195.35.2.238   | 3600
A     | minio         | 195.35.2.238   | 3600
A     | s3            | 195.35.2.238   | 3600
A     | elasticsearch | 195.35.2.238   | 3600
```

#### Développement

```
Type  | Nom                 | Valeur         | TTL
------|---------------------|----------------|-----
A     | grafana.dev         | 195.35.2.238   | 3600
A     | prometheus.dev      | 195.35.2.238   | 3600
A     | minio.dev           | 195.35.2.238   | 3600
A     | s3.dev              | 195.35.2.238   | 3600
A     | elasticsearch.dev   | 195.35.2.238   | 3600
```

---

## Option 2: Wildcard DNS (Plus Simple)

Si vous voulez que **tous** les sous-domaines pointent vers votre serveur:

```
Type  | Nom    | Valeur         | TTL
------|--------|----------------|-----
A     | @      | 195.35.2.238   | 3600
A     | *      | 195.35.2.238   | 3600
A     | *.dev  | 195.35.2.238   | 3600
```

**Avantages:**
- Un seul enregistrement à gérer
- Tous les sous-domaines fonctionnent automatiquement
- Facilite l'ajout de nouveaux services

---

## Configuration par Registrar

### OVH

1. Connexion à l'espace client OVH
2. **Web Cloud** → **Domaines** → `amoona.tech`
3. Onglet **Zone DNS**
4. **Ajouter une entrée**:

```
# Production (wildcard)
@              IN A     195.35.2.238
*              IN A     195.35.2.238

# Développement (wildcard)
*.dev          IN A     195.35.2.238
```

### Cloudflare

1. Dashboard Cloudflare → Sélectionner `amoona.tech`
2. Section **DNS** → **Add record**

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `@` | `195.35.2.238` | DNS only |
| A | `*` | `195.35.2.238` | DNS only |
| A | `*.dev` | `195.35.2.238` | DNS only |

> **Important**: Désactivez le proxy Cloudflare (nuage orange → gris) pour les wildcards si vous utilisez cert-manager.

### Gandi

1. Connexion à Gandi
2. **Mes domaines** → `amoona.tech`
3. **Enregistrements DNS** → **Ajouter un enregistrement**
4. Type: **A**, Nom: `*`, Valeur: `195.35.2.238`

### Google Domains / Squarespace

1. Console Google Domains
2. **Mes domaines** → `amoona.tech`
3. **DNS** → **Gérer les enregistrements personnalisés**
4. **Créer un enregistrement**: Type A, Nom `*`, Données `195.35.2.238`

---

## Vérification de la Configuration DNS

### Vérifier la Propagation

```bash
# Vérifier un sous-domaine spécifique
dig grafana.amoona.tech +short
nslookup grafana.amoona.tech

# Vérifier tous les sous-domaines
for subdomain in grafana prometheus minio s3 elasticsearch; do
  echo -n "$subdomain.amoona.tech: "
  dig +short $subdomain.amoona.tech
done

# Vérifier les sous-domaines dev
for subdomain in grafana prometheus minio s3 elasticsearch; do
  echo -n "$subdomain.dev.amoona.tech: "
  dig +short $subdomain.dev.amoona.tech
done
```

### Outils en Ligne

- **DNS Checker**: https://dnschecker.org/
- **DNS Propagation**: https://www.whatsmydns.net/

### Temps de Propagation

**Délai**: 1-48 heures (généralement 1-4 heures)

---

## Configuration SSL/TLS avec Let's Encrypt

### 1. Installer cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Attendre que cert-manager soit prêt
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
```

### 2. Créer un ClusterIssuer

```yaml
# cluster-issuer.yaml
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

```bash
kubectl apply -f cluster-issuer.yaml
```

### 3. Vérifier les Certificats

```bash
# Voir les certificats
kubectl get certificates -A

# Détails
kubectl describe certificate -n amoona-prod
```

---

## Tests Complets

### Script de Test

```bash
#!/bin/bash
# test-domains.sh

echo "=== Test des sous-domaines amoona.tech ==="
echo ""

# Production
echo "--- Production (amoona-prod) ---"
for subdomain in grafana prometheus minio s3 elasticsearch; do
  domain="$subdomain.amoona.tech"
  echo -n "$domain: "
  IP=$(dig +short $domain | head -n1)
  if [ -z "$IP" ]; then
    echo "❌ DNS non résolu"
  else
    echo "✅ $IP"
  fi
done

echo ""
echo "--- Développement (amoona-dev) ---"
for subdomain in grafana prometheus minio s3 elasticsearch; do
  domain="$subdomain.dev.amoona.tech"
  echo -n "$domain: "
  IP=$(dig +short $domain | head -n1)
  if [ -z "$IP" ]; then
    echo "❌ DNS non résolu"
  else
    echo "✅ $IP"
  fi
done

echo ""
echo "=== Tests terminés ==="
```

### Tester les URLs

```bash
# Test HTTP (dev - pas de SSL)
curl -I http://grafana.dev.amoona.tech

# Test HTTPS (prod - avec SSL)
curl -I https://grafana.amoona.tech

# Vérifier le certificat SSL
openssl s_client -connect grafana.amoona.tech:443 -servername grafana.amoona.tech
```

---

## Ajouter un Nouveau Service

### 1. Créer le Service avec le Script

```bash
./scripts/create-service.sh mon-api
```

### 2. Ajouter l'Enregistrement DNS

Chez votre registrar, ajoutez:
- `mon-api.amoona.tech` → `195.35.2.238` (prod)
- `mon-api.dev.amoona.tech` → `195.35.2.238` (dev)

Ou utilisez le wildcard `*` qui couvre automatiquement tous les sous-domaines.

### 3. Mettre à Jour l'Ingress

Ajoutez dans `k8s/overlays/prod/ingress-patch.yaml`:

```yaml
# Sous spec.tls[0].hosts:
- mon-api.amoona.tech

# Sous spec.rules:
- host: mon-api.amoona.tech
  http:
    paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mon-api
            port:
              number: 8080
```

### 4. Déployer

```bash
git add k8s/
git commit -m "feat: add mon-api ingress"
git push origin main
```

---

## Dépannage

### DNS ne résout pas

```bash
# Vider le cache DNS local
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns

# Tester avec DNS public
dig @8.8.8.8 grafana.amoona.tech
dig @1.1.1.1 grafana.amoona.tech
```

### Certificat SSL invalide

```bash
# Vérifier cert-manager
kubectl get pods -n cert-manager
kubectl logs -n cert-manager -l app=cert-manager

# Vérifier les challenges ACME
kubectl get challenges -A
kubectl describe challenge <name> -n <namespace>
```

### 502 Bad Gateway

```bash
# Vérifier les services
kubectl get svc -n amoona-prod

# Vérifier les pods
kubectl get pods -n amoona-prod

# Logs Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

### Vérifier l'Ingress

```bash
# Voir tous les Ingress
kubectl get ingress -A

# Détails
kubectl describe ingress amoona-ingress -n amoona-prod
```

---

## Récapitulatif

### URLs de Production

| Service | URL |
|---------|-----|
| Grafana | https://grafana.amoona.tech |
| Prometheus | https://prometheus.amoona.tech |
| MinIO Console | https://minio.amoona.tech |
| MinIO S3 API | https://s3.amoona.tech |
| Elasticsearch | https://elasticsearch.amoona.tech |

### URLs de Développement

| Service | URL |
|---------|-----|
| Grafana | http://grafana.dev.amoona.tech |
| Prometheus | http://prometheus.dev.amoona.tech |
| MinIO Console | http://minio.dev.amoona.tech |
| MinIO S3 API | http://s3.dev.amoona.tech |
| Elasticsearch | http://elasticsearch.dev.amoona.tech |

### Checklist

- [ ] Enregistrements DNS configurés (wildcard ou individuels)
- [ ] Propagation DNS vérifiée (`dig`, `nslookup`)
- [ ] Port 6443 ouvert (API Kubernetes)
- [ ] Port 80/443 ouvert (HTTP/HTTPS)
- [ ] cert-manager installé
- [ ] ClusterIssuer créé
- [ ] Certificats SSL générés
- [ ] Tests HTTPS réussis

---

## Ressources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [DNS Propagation Checker](https://www.whatsmydns.net/)
