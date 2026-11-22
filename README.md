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

