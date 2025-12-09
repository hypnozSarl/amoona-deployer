# Configuration Angular pour Kubernetes

Ce guide explique comment configurer une application Angular pour le deploiement sur Kubernetes avec Amoona.

## Structure Recommandee

```
k8s/base/apps/frontend/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
└── kustomization.yaml
```

## Dockerfile

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS build
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build -- --configuration production

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy built app
COPY --from=build /app/dist/*/browser /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Non-root user
RUN chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Configuration Nginx

### nginx.conf

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript
               application/javascript application/json
               application/xml application/rss+xml
               font/truetype font/opentype
               image/svg+xml;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # SPA routing - return index.html for all routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # API proxy (optional - if not using ingress)
    location /api/ {
        proxy_pass http://backend:8080/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
```

## Configuration Angular

### environment.prod.ts

```typescript
export const environment = {
  production: true,
  apiUrl: '/api',  // Proxied through nginx or ingress
  // Or direct URL if using separate domains:
  // apiUrl: 'https://api.amoona.tech',
};
```

### angular.json (build configuration)

```json
{
  "configurations": {
    "production": {
      "budgets": [
        {
          "type": "initial",
          "maximumWarning": "500kb",
          "maximumError": "1mb"
        }
      ],
      "outputHashing": "all",
      "optimization": true,
      "sourceMap": false,
      "namedChunks": false,
      "extractLicenses": true
    }
  }
}
```

## Manifestes Kubernetes

### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
    component: ui
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        component: ui
    spec:
      containers:
        - name: frontend
          image: your-registry/frontend:latest
          ports:
            - containerPort: 80
              name: http
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
          livenessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            runAsNonRoot: true
            runAsUser: 101  # nginx user
```

### service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
      name: http
  selector:
    app: frontend
```

### kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  tier: frontend
```

## Configuration Runtime avec ConfigMap

Pour injecter la configuration a l'execution:

### config.json

```json
{
  "apiUrl": "https://api.amoona.tech",
  "features": {
    "darkMode": true,
    "analytics": false
  }
}
```

### configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
data:
  config.json: |
    {
      "apiUrl": "https://api.amoona.tech",
      "features": {
        "darkMode": true,
        "analytics": false
      }
    }
```

### Monter dans le deployment

```yaml
spec:
  containers:
    - name: frontend
      volumeMounts:
        - name: config
          mountPath: /usr/share/nginx/html/assets/config.json
          subPath: config.json
  volumes:
    - name: config
      configMap:
        name: frontend-config
```

### Charger dans Angular

```typescript
// config.service.ts
@Injectable({ providedIn: 'root' })
export class ConfigService {
  private config: any;

  async loadConfig(): Promise<void> {
    const response = await fetch('/assets/config.json');
    this.config = await response.json();
  }

  get apiUrl(): string {
    return this.config?.apiUrl || environment.apiUrl;
  }
}

// app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    {
      provide: APP_INITIALIZER,
      useFactory: (configService: ConfigService) => () => configService.loadConfig(),
      deps: [ConfigService],
      multi: true
    }
  ]
};
```

## Ingress avec SSL

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.amoona.tech
      secretName: frontend-tls
  rules:
    - host: app.amoona.tech
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```

## Build et Deploy

```bash
# Build l'image Docker
docker build -t your-registry/frontend:v1.0.0 .

# Push
docker push your-registry/frontend:v1.0.0

# Mettre a jour le deployment
kubectl set image deployment/frontend frontend=your-registry/frontend:v1.0.0 -n amoona-dev

# Verifier le rollout
kubectl rollout status deployment/frontend -n amoona-dev
```

## Optimisations

### 1. Bundle Size

```bash
# Analyser le bundle
npm run build -- --stats-json
npx webpack-bundle-analyzer dist/*/browser/stats.json
```

### 2. Lazy Loading

```typescript
// app.routes.ts
export const routes: Routes = [
  {
    path: 'admin',
    loadChildren: () => import('./admin/admin.routes').then(m => m.ADMIN_ROUTES)
  }
];
```

### 3. Service Worker (PWA)

```bash
ng add @angular/pwa
```

## Bonnes Pratiques

1. **Multi-stage Docker build** - image finale legere
2. **Nginx pour servir** - performant et configurable
3. **Health checks** - endpoint /health simple
4. **Configuration runtime** - ConfigMaps pour les variables d'environnement
5. **Cache headers** - cache agressif pour les assets immutables
6. **Gzip compression** - reduire la bande passante
7. **Security headers** - X-Frame-Options, CSP, etc.
8. **Utilisateur non-root** - securite du conteneur
