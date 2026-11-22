# dso202-gitops
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
