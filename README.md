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
