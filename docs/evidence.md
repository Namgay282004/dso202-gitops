<!--
File        : docs/evidence.md
Assignment  : DSO202 Assignment 4
Purpose     : Records command outputs and verification evidence for each task.
-->

# DSO202 Assignment 4 — Evidence

## Task 1

### Repository, Chart Contract and Cluster

The Assignment 4 repository reuses the Helm chart from
Assignment 3, resource restrictions from Assignment 2,
and the Kind cluster configuration from Practical 1.

The namespace-scoped Role and RoleBinding manifests were
recreated because the original Assignment 2 RBAC manifests
were unavailable in the local assignment files.

### Chart Contract Verification

All chart file paths below are relative to charts/tasktracker/
unless otherwise stated.

| ID | Requirement | File and key | Result |
|---|---|---|---|
| C1 | Configurable image repositories and tags | values.yaml: database.image, backend.image, frontend.image; corresponding workload templates | PASS |
| C2 | Per-tier configuration rendered from values | values.yaml: database.env, backend.env, frontend.env; templates/configmap.yaml and workload envFrom references | PASS |
| C3 | Existing Secret references without rendering Secrets | values.yaml: existingSecret; templates/backend-deploy.yaml and templates/db-statefulset.yaml: secretKeyRef | PASS |
| C4 | Readiness probes on all three tiers | templates/backend-deploy.yaml: readinessProbe.httpGet.path=/api/status; templates/frontend-deploy.yaml: readinessProbe; templates/db-statefulset.yaml: readinessProbe.exec | PASS |
| C5 | Workload sync waves | templates/db-statefulset.yaml: wave 0; templates/backend-deploy.yaml: wave 1; templates/frontend-deploy.yaml: wave 2 | PASS |
| C6 | Rollout deadlines | templates/backend-deploy.yaml and templates/frontend-deploy.yaml: progressDeadlineSeconds=120 | PASS |
| C7 | Explicit resource requests and limits | values.yaml: database.resources, backend.resources, frontend.resources; corresponding workload templates | PASS |
| C8 | No platform resources rendered | templates/ contains only workload and application configuration resources; platform restrictions remain in platform/dev/ and platform/staging/ | PASS |
| C9 | Ingress disabled | values.yaml: ingress.enabled=false; no Ingress template or rendered Ingress | PASS |
| C10 | Environment-specific NodePorts | templates/frontend-deploy.yaml: service type and nodePort; environments/dev/values.yaml: 30080; environments/staging/values.yaml: 30081 | PASS |
| C11 | Helm lint and template rendering | Both environment values files successfully validated using helm lint and helm template | PASS |

The chart contract was verified through static rendering.
Live application readiness and rollout behaviour are tested
in the later deployment tasks.


### Tool Verification (Section 3.2)

```text
$ docker version --format "{{.Server.Version}}"
27.5.1

$ kind version
kind v0.32.0 go1.26.5 linux/amd64

$ kubectl version --client
Client Version: v1.36.3
Kustomize Version: v5.8.1

$ helm version --short
v4.3.0+gbec5b06

$ git --version
git version 2.34.1

$ argocd version --client
argocd: v3.5.6+c2b1e30
  BuildDate: 2026-10-20T19:01:52Z
  GitCommit: c2b1e3017e2cec86b122172e861dcd026453ae44
  GitTreeState: clean
  GoVersion: go1.26.10
  Compiler: gc
  Platform: linux/amd64

$ kubeseal --version
kubeseal version: 0.40.0

$ helm repo list
NAME          	URL                                     
hashicorp     	https://helm.releases.hashicorp.com     
kong          	https://charts.konghq.com               
bitnami       	https://charts.bitnami.com/bitnami      
podinfo       	https://stefanprodan.github.io/podinfo  
dso202-argo   	https://argoproj.github.io/argo-helm    
sealed-secrets	https://bitnami.github.io/sealed-secrets

$ helm search repo sealed-secrets/sealed-secrets --versions | head -5
NAME                         	CHART VERSION	APP VERSION	DESCRIPTION                                  
sealed-secrets/sealed-secrets	2.22.0       	0.41.2     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.21.0       	0.41.2     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.20.0       	0.40.0     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.19.3       	0.39.1     	Helm chart for the sealed-secrets controller.
```

### Repository History

```text
$ git log --oneline --reverse
be2c43d chore: add gitignore to protect secrets and key material
089e074 docs: initialize DSO202 GitOps repository

$ git remote -v
origin	https://github.com/Namgay282004/dso202-gitops.git (fetch)
origin	https://github.com/Namgay282004/dso202-gitops.git (push)
```

### Kind Cluster Verification

```text
$ kind get clusters
dso202-gitops
kind

$ kubectl config current-context
kind-dso202-gitops

$ kubectl get nodes
NAME            STATUS   ROLES           AGE   VERSION
control-plane   Ready    control-plane   16d   v1.36.1
worker-node-1   Ready    <none>          16d   v1.36.1
worker-node-2   Ready    <none>          16d   v1.36.1

$ docker ps --filter name=dso202-gitops
dso202-gitops-worker2 
dso202-gitops-control-plane 127.0.0.1:30080->30080/tcp, 127.0.0.1:43441->6443/tcp
dso202-gitops-worker 
```

### Helm Lint and Template Verification

#### Environment: dev

```text
$ helm lint charts/tasktracker -f environments/dev/values.yaml
==> Linting charts/tasktracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm template tasktracker charts/tasktracker --namespace dso202-dev -f environments/dev/values.yaml

$ grep "^kind:" rendered-manifest | sort | uniq -c
      3 kind: ConfigMap
      2 kind: Deployment
      3 kind: Service
      1 kind: StatefulSet
```

#### Environment: staging

```text
$ helm lint charts/tasktracker -f environments/staging/values.yaml
==> Linting charts/tasktracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm template tasktracker charts/tasktracker --namespace dso202-staging -f environments/staging/values.yaml

$ grep "^kind:" rendered-manifest | sort | uniq -c
      3 kind: ConfigMap
      2 kind: Deployment
      3 kind: Service
      1 kind: StatefulSet
```


### Detailed Chart Contract Checks

#### Environment: dev

```text
$ grep -E "^[[:space:]]+image:" rendered-manifest
          image: "02230290namgay/dso202-backend:1.0"
          image: "02230290namgay/dso202-frontend:1.0"
          image: "02230290namgay/dso202-db:1.0"

$ grep -A 10 readinessProbe: rendered-manifest
          readinessProbe:
            httpGet:
              path: /api/status
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3

          resources:
            limits:
--
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3

          resources:
            limits:
--
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - 'pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 6


$ grep sync-wave annotations and resource names
kind: ConfigMap
  name: tasktracker-database-config
    argocd.argoproj.io/sync-wave: "-1"
kind: ConfigMap
  name: tasktracker-backend-config
    argocd.argoproj.io/sync-wave: "-1"
kind: ConfigMap
  name: tasktracker-frontend-config
    argocd.argoproj.io/sync-wave: "-1"
kind: Service
  name: tasktracker-backend-service
    argocd.argoproj.io/sync-wave: "1"
kind: Service
  name: tasktracker-db-service
    argocd.argoproj.io/sync-wave: "0"
kind: Service
  name: tasktracker-frontend-service
    argocd.argoproj.io/sync-wave: "2"
kind: Deployment
  name: tasktracker-backend-deployment
    argocd.argoproj.io/sync-wave: "1"
kind: Deployment
  name: tasktracker-frontend-deployment
    argocd.argoproj.io/sync-wave: "2"
kind: StatefulSet
  name: tasktracker-db
    argocd.argoproj.io/sync-wave: "0"

$ grep progressDeadlineSeconds: rendered-manifest
  progressDeadlineSeconds: 120
  progressDeadlineSeconds: 120

$ grep -A 6 resources: rendered-manifest
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 200m
              memory: 256Mi
--
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 200m
              memory: 256Mi
--
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 200m
              memory: 256Mi
--
        resources:
          requests:
            storage: 1Gi

  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain
    whenScaled: Retain

$ grep -A 2 secretKeyRef: rendered-manifest
                secretKeyRef:
                  name: "tasktracker-credentials"
                  key: DB_USER
--
                secretKeyRef:
                  name: "tasktracker-credentials"
                  key: DB_PASSWORD
--
                secretKeyRef:
                  name: "tasktracker-credentials"
                  key: POSTGRES_USER
--
                secretKeyRef:
                  name: "tasktracker-credentials"
                  key: POSTGRES_PASSWORD

$ grep NodePort configuration
  type: NodePort
      nodePort: 30080

$ Check forbidden resource kinds
PASS: No forbidden resources rendered
```

#### Environment: staging

```text
$ grep -E "^[[:space:]]+image:" rendered-manifest
          image: "02230290namgay/dso202-backend:1.0"
          image: "02230290namgay/dso202-frontend:1.0"
          image: "02230290namgay/dso202-db:1.0"

$ grep -A 10 readinessProbe: rendered-manifest
          readinessProbe:
            httpGet:
              path: /api/status
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3

          resources:
            limits:
--
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3

          resources:
            limits:
--
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - 'pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 6


$ grep sync-wave annotations and resource names
kind: ConfigMap
  name: tasktracker-database-config
    argocd.argoproj.io/sync-wave: "-1"
kind: ConfigMap
  name: tasktracker-backend-config
    argocd.argoproj.io/sync-wave: "-1"
kind: ConfigMap
  name: tasktracker-frontend-config
    argocd.argoproj.io/sync-wave: "-1"
kind: Service
  name: tasktracker-backend-service
    argocd.argoproj.io/sync-wave: "1"
kind: Service
  name: tasktracker-db-service
    argocd.argoproj.io/sync-wave: "0"
kind: Service
  name: tasktracker-frontend-service
    argocd.argoproj.io/sync-wave: "2"
kind: Deployment
  name: tasktracker-backend-deployment
    argocd.argoproj.io/sync-wave: "1"
kind: Deployment
  name: tasktracker-frontend-deployment
    argocd.argoproj.io/sync-wave: "2"
kind: StatefulSet
  name: tasktracker-db
    argocd.argoproj.io/sync-wave: "0"

$ grep progressDeadlineSeconds: rendered-manifest
  progressDeadlineSeconds: 120
  progressDeadlineSeconds: 120

$ grep -A 6 resources: rendered-manifest
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 200m
              memory: 256Mi
--
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 200m
              memory: 256Mi
--
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 200m
              memory: 256Mi
--
        resources:
          requests:
            storage: 1Gi

  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain
    whenScaled: Retain

$ grep -A 2 secretKeyRef: rendered-manifest
                secretKeyRef:
                  name: "tasktracker-credentials"
                  key: DB_USER
--
                secretKeyRef:
                  name: "tasktracker-credentials"
                  key: DB_PASSWORD
--
                secretKeyRef:
                  name: "tasktracker-credentials"
                  key: POSTGRES_USER
--
                secretKeyRef:
                  name: "tasktracker-credentials"
                  key: POSTGRES_PASSWORD

$ grep NodePort configuration
  type: NodePort
      nodePort: 30081

$ Check forbidden resource kinds
PASS: No forbidden resources rendered
```

### C2 — Configurable Backend Environment Test

```text
$ helm template with backend.env.GITOPS_CONTRACT_TEST=verified
  GITOPS_CONTRACT_TEST: "verified"

$ grep -A 3 envFrom: rendered-manifest
          envFrom:
            - configMapRef:
                name: tasktracker-backend-config

--
          envFrom:
            - configMapRef:
                name: tasktracker-frontend-config

--
          envFrom:
            - configMapRef:
                name: tasktracker-database-config


$ Check that the temporary test value is not saved
PASS: Test value was only used during rendering
```

### Repository Security Verification

| Security check | Result |
|---|---|
| All eight gitignore protection tests | PASS |
| Sensitive filename search | No matching files |
| Plaintext Secret manifest search | No matches |
| Private key search | No matches |
| Previous credential value search | No matches |
| Potential hardcoded credential search | No matches |
| Reachable Git history credential search | No matches |

The initial Git history was inspected before committing
the application configuration.

Actual verification output:

```text
===== CORRECTED PRIVATE KEY SEARCH =====
PASS: No private keys found

===== GIT HISTORY CREDENTIAL SEARCH =====
===== GIT HISTORY FILES =====
.gitignore
README.md
```

These checks reduce the risk of accidentally exposing plaintext
credentials and private key material in the public repository.
They are not a guarantee that every possible secret format has
been detected.

