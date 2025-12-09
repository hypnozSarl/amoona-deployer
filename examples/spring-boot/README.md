# Configuration Spring Boot pour Kubernetes

Ce guide explique comment configurer une application Spring Boot pour le deploiement sur Kubernetes avec Amoona.

## Structure Recommandee

```
k8s/base/apps/backend/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
├── secret.yaml
└── kustomization.yaml
```

## Dockerfile

```dockerfile
# Multi-stage build
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw dependency:go-offline -B
COPY src src
RUN ./mvnw package -DskipTests -B

# Runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

# Non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

## Configuration Application

### application-prod.yml

```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5

  data:
    redis:
      host: ${SPRING_REDIS_HOST:redis}
      port: ${SPRING_REDIS_PORT:6379}

  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false

# Actuator pour health checks et metriques
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  endpoint:
    health:
      probes:
        enabled: true
      show-details: always
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}

# Logging
logging:
  level:
    root: INFO
    org.springframework: WARN
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
```

### pom.xml - Dependencies

```xml
<dependencies>
    <!-- Actuator pour health checks -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>

    <!-- Prometheus metrics -->
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>

    <!-- PostgreSQL -->
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <scope>runtime</scope>
    </dependency>

    <!-- Redis -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-redis</artifactId>
    </dependency>
</dependencies>
```

## Manifestes Kubernetes

### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
    component: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        component: api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      containers:
        - name: backend
          image: your-registry/backend:latest
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "prod"
            - name: SPRING_DATASOURCE_URL
              value: "jdbc:postgresql://postgres:5432/amoona_db"
            - name: SPRING_REDIS_HOST
              value: "redis"
          envFrom:
            - secretRef:
                name: backend-secret
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 30
```

### service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  labels:
    app: backend
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
      name: http
  selector:
    app: backend
```

### secret.yaml

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
type: Opaque
stringData:
  SPRING_DATASOURCE_USERNAME: amoona
  SPRING_DATASOURCE_PASSWORD: changeme
  JWT_SECRET: your-jwt-secret-at-least-32-characters
```

### kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - secret.yaml

commonLabels:
  tier: backend
```

## Integration avec MinIO

```java
@Configuration
public class MinioConfig {

    @Value("${minio.endpoint}")
    private String endpoint;

    @Value("${minio.access-key}")
    private String accessKey;

    @Value("${minio.secret-key}")
    private String secretKey;

    @Bean
    public MinioClient minioClient() {
        return MinioClient.builder()
            .endpoint(endpoint)
            .credentials(accessKey, secretKey)
            .build();
    }
}
```

Variables d'environnement:
```yaml
- name: MINIO_ENDPOINT
  value: "http://minio:9000"
- name: MINIO_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: minio-secret
      key: MINIO_ROOT_USER
- name: MINIO_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: minio-secret
      key: MINIO_ROOT_PASSWORD
```

## Integration avec Elasticsearch

```java
@Configuration
public class ElasticsearchConfig {

    @Value("${elasticsearch.host}")
    private String host;

    @Bean
    public RestClient restClient() {
        return RestClient.builder(
            new HttpHost(host, 9200, "http")
        ).build();
    }
}
```

## Health Checks Personnalises

```java
@Component
public class DatabaseHealthIndicator implements HealthIndicator {

    private final DataSource dataSource;

    @Override
    public Health health() {
        try (Connection conn = dataSource.getConnection()) {
            if (conn.isValid(1)) {
                return Health.up()
                    .withDetail("database", "PostgreSQL")
                    .build();
            }
        } catch (SQLException e) {
            return Health.down()
                .withException(e)
                .build();
        }
        return Health.down().build();
    }
}
```

## Build et Deploy

```bash
# Build l'image Docker
docker build -t your-registry/backend:v1.0.0 .

# Push
docker push your-registry/backend:v1.0.0

# Mettre a jour le deployment
kubectl set image deployment/backend backend=your-registry/backend:v1.0.0 -n amoona-dev

# Verifier le rollout
kubectl rollout status deployment/backend -n amoona-dev
```

## Bonnes Pratiques

1. **Toujours utiliser les probes** - liveness, readiness, startup
2. **Externaliser la configuration** - ConfigMaps et Secrets
3. **Definir les ressources** - requests et limits
4. **Logger en JSON** - facilite l'agregation avec Elasticsearch
5. **Exposer les metriques** - /actuator/prometheus
6. **Utiliser des utilisateurs non-root** dans les conteneurs
