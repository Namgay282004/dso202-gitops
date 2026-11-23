# DSO202 Assignment 4 — GitOps with Argo CD

## Project Overview

This repository implements GitOps-based deployment of the
Task Tracker application using Kubernetes, Helm, Argo CD,
and Sealed Secrets.

The application is deployed to two environments:

- Development (`dso202-dev`): follows the `main` branch
  with automated synchronization, pruning, and self-healing.
- Staging (`dso202-staging`): follows a pinned Git release
  tag and requires manual synchronization.

The repository also includes Kubernetes platform policies,
Argo CD AppProjects, application definitions, encrypted
SealedSecrets, and disaster recovery documentation.

## Repository

- GitHub: https://github.com/Namgay282004/dso202-gitops
- Main branch: `main`
- Release tags: `v1.0.0`, `v1.1.0`, `v1.2.0`
- Cluster name: `dso202-gitops`

## Verified Tool Versions

| Component | Version |
|---|---|
| Docker Engine | 28.3.3 |
| Kind | 0.32.0 |
| Kubernetes node | 1.36.1 (digest pinned in cluster configuration) |
| kubectl | 1.36.3 |
| Helm CLI | 4.3.0 |
| Argo CD | 3.5.6 |
| Sealed Secrets Helm chart | 2.20.0 |
| kubeseal | 0.40.0 |
| Git | 2.34.1 |

The Kind node image is pinned to an immutable SHA-256 digest
in `cluster/kind-cluster.yaml`.

Argo CD is installed from its pinned v3.5.6 release
manifest. Sealed Secrets uses Helm chart version 2.20.0.

## Documentation

- `docs/evidence.md`: command outputs, observations,
  and verification evidence for Tasks 01–09.
- `evidences/`: supporting screenshots organized by task.
- `charts/tasktracker/`: Helm chart for the application.
- `environments/`: development and staging Helm values.
- `platform/`: namespace policies and encrypted credentials.
- `argocd/`: declarative Applications and AppProjects.
- `bootstrap/`: initial Argo CD and root Application setup.
- `cluster/`: reproducible Kind cluster configuration.

---

## Rebuild from an Empty Kind Cluster

The following is the documented Task 9 recovery procedure, **not a command to run during submission**. On a new machine, install Docker, Git, Kind, kubectl, Helm, Argo CD CLI and kubeseal. Use the pinned versions listed above; Docker must be running. The separately secured Sealed Secrets key backup is an external recovery dependency and is **not in Git**. Commands assume the backup is available at the stated sibling path.

```bash
git clone https://github.com/Namgay282004/dso202-gitops.git
cd dso202-gitops
kind create cluster --name dso202-gitops --config cluster/kind-cluster.yaml
kubectl get nodes
```

Restore the original sealing key **before** the Sealed Secrets controller is installed. Do not print or commit the key backup.

```bash
kubectl create namespace sealed-secrets
kubectl apply -f ../dso202-keys/sealing-key.backup.yaml
kubectl apply -k bootstrap/argocd --server-side --force-conflicts
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
kubectl apply -f bootstrap/root
kubectl get applications -n argocd -w
```

The root Application reconciles the remaining AppProjects and Applications from Git. Development follows `main` with automated synchronization, pruning and self-healing. Staging follows pinned release `v1.2.0` and **must be synchronized manually**.

Start the Argo CD port-forward in a separate terminal:

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

In the main terminal, retrieve the newly generated administrator password privately and log in. Never record the password in screenshots or Git.

```bash
argocd admin initial-password -n argocd
argocd login localhost:8080 --username admin --insecure
argocd app sync tasktracker-staging
kubectl get applications -n argocd
kubectl get deployments,statefulsets,jobs -n dso202-dev
kubectl get deployments,statefulsets,jobs -n dso202-staging
kubectl logs job/tasktracker-smoke-test -n dso202-dev
kubectl logs job/tasktracker-smoke-test -n dso202-staging
```

The development frontend is reachable at `http://localhost:30080`. The Kind host port mapping does **not** expose staging NodePort 30081; use a separate terminal for:

```bash
kubectl port-forward -n dso202-staging svc/tasktracker-frontend-service 8081:80
```

Open `http://localhost:8081` for staging. Verify CRUD operations and both environments' API and smoke tests. After recovery, refresh the protected sealing-key backup using the Task 4 procedure, retaining the file outside Git with restrictive permissions. Task 9 evidence and timings are in `docs/evidence.md` and `evidences/task-09/`. The previous database contents are not recovered by GitOps.

## Cleanup

**Destructive — only run when intentionally removing the local lab:**

```bash
kind delete cluster --name dso202-gitops
```

Stop port-forward terminals with Ctrl+C. Cluster deletion destroys its local database contents, but not the Git repository or the separately protected key backup.

## Credential Handling

The chart refers to existing Kubernetes Secrets; it does not render plaintext Secret resources. Git contains encrypted SealedSecret manifests for both environments. The Sealed Secrets controller decrypts them inside the cluster. Strict scope binds encrypted values to the Secret name and namespace. Plaintext input files (`secrets-plain/`) and the private sealing-key backup (`../dso202-keys/sealing-key.backup.yaml`) are excluded from Git. The backup file is permission `600`, with its directory restricted to `700`. Access to the private key would permit decryption of credentials encrypted for its corresponding public key. Database contents require a separate production backup strategy.

---

## Written Questions

### Q1 — AppProject Boundaries and Bootstrap

**Why is the platform project applied by hand while dso202 is created
by the root Application, and which risk arises if dso202 is allowed
to deploy into the argocd namespace?**

The platform AppProject is applied manually because the root
Application depends on it. The platform project must exist before
the root Application can use its repository and destination
permissions. Without this initial project, the root Application
would not have a valid project through which to synchronize its
resources.

The dso202 AppProject is created by the root Application because
it is part of the desired state stored in Git. This follows the
GitOps approach, where changes are committed to Git and Argo CD
automatically applies them to the cluster. Its sync wave of -3
ensures that the project exists before Applications that depend
on it are created.

Allowing the dso202 project to deploy into the argocd namespace
would weaken the separation between application workloads and
administrative resources. If suitable resource permissions were
also available, a malicious or incorrect manifest could modify
Argo CD configuration, Applications or project definitions.
This could lead to privilege escalation, changes to deployment
restrictions or unauthorized access to other environments.

Therefore, the dso202 project is restricted to the dso202-dev
and dso202-staging namespaces, one Git repository and an explicit
whitelist of workload resource kinds. Administrative deployment
permissions remain with the platform project.


### Q2 — Sealed Secrets scope and key recovery

**Question:** What does strict scope prevent, and what is lost,
and what must be done, if the sealing key is lost?

**Answer:**

Strict scope binds an encrypted SealedSecret to its original
Secret name and Kubernetes namespace. It prevents someone from
copying the encrypted credentials into a different namespace
or renaming the Secret and decrypting it there.

For example, the SealedSecret created for tasktracker-credentials
in dso202-dev cannot be moved directly to dso202-staging and
successfully decrypted. Each environment requires credentials
sealed for its own name and namespace.

If the private sealing key is lost, the SealedSecrets encrypted
with that key can no longer be decrypted unless another copy
of the matching private key is available. The encrypted YAML
files in Git alone are not sufficient to recover their original
credential values.

Existing Kubernetes Secrets may continue to work while they
remain in the cluster. However, they cannot be recreated from
the affected SealedSecrets after deletion or a cluster rebuild
without the matching sealing key.

If a valid backup exists, the private sealing key and its
certificate must be restored to the Sealed Secrets controller.
The controller must load the restored key before the existing
SealedSecrets can be decrypted again.

If no backup exists, the original credentials must be recovered
from another secure source or replaced with new credentials.
The credentials must then be encrypted using the new controller
certificate and the new SealedSecret manifests committed to Git.
Any dependent database and application credentials must also
be updated consistently when credentials are replaced.

For this assignment, the sealing key backup is stored outside
the Git repository at:

    ../dso202-keys/sealing-key.backup.yaml

The backup directory uses permission 700, and the backup file
uses permission 600. The actual key material is never committed
to Git. For reliable disaster recovery, a protected backup should
also be maintained separately from the original machine.

The key restoration and cluster recovery process will be
demonstrated in Task 9.


### Q3 — Synced versus Healthy

**Synced** means the live Kubernetes resources match the desired manifests at the Application's selected Git revision. **Healthy** means Argo CD's health assessments report that those resources are functioning as expected. These are independent: an Application can be Synced while its Deployment is unavailable or its Job is failing.

In Task 5, staging initially required a manual sync: the root Application could have its child Application definitions synchronized from Git while the unsynchronized staging workload was still Missing/Progressing. Another reproducible example is a Deployment whose desired image and manifest have been applied (Synced) but whose Pod fails readiness checks (not Healthy). The recorded Task 5 observations and Application status outputs are in `docs/evidence.md`.

### Q4 — Argo CD RBAC, Kubernetes RBAC, and SSO

**Argo CD RBAC** authorizes operations through Argo CD, such as viewing Applications, reading logs, synchronizing workloads and accessing projects. It is configured in the Argo CD `argocd-rbac-cm` ConfigMap via `policy.csv` and related settings, represented in `bootstrap/argocd/argocd-rbac-cm-patch.yaml`. In Task 6, `reviewer` could read only the `dso202` project Applications, could not sync, and received log access only after an explicit policy rule was committed and the bootstrap layer reapplied.

**Kubernetes RBAC** controls Kubernetes API access to resources using Roles, ClusterRoles, RoleBindings and ClusterRoleBindings. The application namespace policies from Assignment 2 are maintained under `platform/dev/` and `platform/staging/`; they do not grant the reviewer permission to synchronize Argo CD Applications.

With an organizational identity provider connected through SSO, `policy.csv` would normally map authenticated identity-provider groups to Argo CD roles using `g, <identity-provider-group>, <role>` rules. The `p, ...` permission rules could remain role-based, while the local `reviewer` account would no longer be needed for that identity. SSO was **not** configured in this assignment.

### Q5 — Rollback, Fix-Forward and Staging Protection

**Question: Why was the Argo CD rollback refused, how was the failed release recovered, and how was staging protected?**

**Answer:**

The backend 1.1 release was introduced through a GitHub pull request.
After merging, Argo CD automatically attempted to deploy it to development.

The backend failed to start because the required RELEASE_MODE environment
variable was missing. The Pod entered CrashLoopBackOff, and Argo CD
reported the development application as Degraded. Kubernetes logs
confirmed the missing environment variable.

An Argo CD rollback was attempted but refused because automated
synchronization was enabled. Therefore, recovery was performed through
a Git revert instead.

The revert restored backend 1.0 through a separate pull request.
After merging, Argo CD automatically synchronized development,
and the application returned to Synced and Healthy.

The backend 1.1 release was then corrected using a fix-forward change.
The required RELEASE_MODE environment variable was set to enabled
in the Helm configuration. Helm lint and template rendering confirmed
the corrected configuration before merging.

After the fix-forward merge, development successfully deployed backend
1.1. The backend connected to the database, both API endpoints returned
HTTP 200, and the PostSync smoke-test Job succeeded.

The corrected release was tagged as v1.2.0.

Staging was protected because it used a fixed Git tag and manual
synchronization. While development experienced the failed release,
staging remained on the stable v1.1.0 release.

A separate pull request promoted staging to v1.2.0. The application
remained OutOfSync until manual synchronization was performed.

After manual synchronization, staging became Synced and Healthy.
Backend 1.1 started successfully, the database was connected,
both API endpoints returned HTTP 200, and the smoke test succeeded.

The staging deployment history contained v1.0.0, v1.1.0, and v1.2.0.
It did not contain the faulty commit d4102e6. This confirmed that
the faulty backend release was never deployed to staging.

This exercise demonstrated how Git revert restores a stable state,
fix-forward corrects failed releases, and manual staging promotion
prevents unverified changes from reaching staging.


`git revert` creates an auditable inverse commit while preserving the original faulty change and its investigation history; deleting or rewriting the bad commit would break the shared history that GitOps and reviewers rely on.
### Q6 — Repository Trade-offs and Recovery Boundaries

**(a) One repository for chart and environment configuration.** Two advantages are (1) a single pull request can review application deployment definitions and environment values together, and (2) releases and disaster recovery are easier to trace because related configuration lives in one versioned history. Two disadvantages are (1) changes to application and environment configuration have a shared review/access boundary, making least-privilege ownership harder, and (2) the repository can become noisy and tightly coupled as teams and environments grow. Separate application-source and deployment-configuration repositories can support independent access and release lifecycles.

**(b) What GitOps does not restore automatically.**

- **Kind cluster and underlying host/Docker:** Git records the cluster configuration, but creating the host and cluster is an external bootstrap action; production teams typically use infrastructure-as-code and managed infrastructure provisioning.
- **Argo CD installation and its bootstrap ConfigMaps:** These are installed by `kubectl apply -k bootstrap/argocd`, outside Argo CD's own reconciliation; production teams typically provision and upgrade this bootstrap layer through infrastructure automation or a dedicated platform deployment pipeline.
- **Initial platform AppProject and root Application:** The bootstrap objects in `bootstrap/root/` must be applied before the root can reconcile children; production teams typically manage these foundational resources using a controlled bootstrap process.
- **Sealed Secrets private key:** Git stores encrypted SealedSecrets but not the private key; production teams store, rotate, back up and restore encryption keys using restricted secret-management and disaster-recovery processes.
- **Database contents and persistent data:** Git stores deployment configuration, not user-created task records; production teams use database backups, point-in-time recovery and restore testing.
- **Manual staging approval:** The Git tag is declarative, but the act of authorizing a manual sync is an operational decision; production teams typically use protected promotion workflows and audited approvals.

Task 9 proved that the deployment configuration and credentials could be recovered using Git plus the protected key backup; previous database contents were intentionally lost.
