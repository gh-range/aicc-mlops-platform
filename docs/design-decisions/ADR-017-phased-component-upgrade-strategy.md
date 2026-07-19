# ADR-017: Phased Component Upgrade Strategy

## Status
Accepted

## Date
2026-07-20

## Context

### Problem Statement
The AICC MLOps Platform had been paused for several months. Before reinstalling the OS (Ubuntu 24.04 -> 26.04), all core Helm-managed components required upgrading to their latest supported versions to avoid carrying stale, unsupported configurations into the new baseline. The components involved (Traefik, cert-manager, GPU Operator, JupyterHub) had accumulated multiple version generations of drift, most notably Traefik, which was several major chart versions behind (v3.6.15 image / older chart series -> chart 41.0.2).

### Technical Environment
- **Orchestration**: k3s v1.35.5 (embedded etcd HA)
- **GPU Stack**: NVIDIA Driver 610.43.02, CUDA 13.3, GPU Operator target v26.3.3
- **Ingress**: Traefik, target chart v41.0.2
- **CNI**: Calico v3.31.3 (policy-only mode, coexisting with Flannel)
- **Constraint**: Single-node lab environment (no staging cluster); any breaking change directly impacts the only available environment used for interview demonstrations

---

## Decision Drivers

- **Blast Radius**: No staging/canary cluster exists; a failed jump upgrade risks total platform downtime with no fast rollback path other than etcd snapshot restore
- **Schema Drift Risk**: Multi-major-version Helm chart jumps (e.g., Traefik 39x -> 41x) frequently introduce breaking `values.yaml` schema changes that are not visible from a single `--dry-run` pass across the full version gap
- **Time Budget**: This is a scheduled maintenance window ahead of an OS reinstall, not an ongoing production SLA; some extra time spent validating intermediate versions is acceptable and preferable to a failed cutover
- **SuperPod Scalability**: GPU Operator and driver/CUDA version alignment must remain compatible with the eventual migration path to NVIDIA H200/B200/B300 SuperPods; skipping intermediate GPU Operator versions increases the risk of undetected time-slicing or DCGM regressions
- **TCO/OPEX**: Avoiding a broken cluster before OS reinstall protects against unplanned rebuild time, which directly affects the progress of the project

---

## Considered Options

### Option 1: Direct Jump Upgrade (Single-Step, Latest Version Only)

**Description**: Upgrade each component directly from its current version to the final target version in a single `helm upgrade` call per component.

**Pros:**
- [o] Fewer commands, faster to execute
- [o] Fewer intermediate verification checkpoints to manage

**Cons:**
- [x] Chart schema changes across multiple major versions are aggregated into a single diff, making root-cause isolation difficult on failure
- [x] No intermediate rollback point between "known good" and "final target"
- [x] Higher risk of an unrecoverable `values.yaml` mismatch going undetected until the final `helm upgrade` is already applied

**Cost Estimate**: Lower time cost if successful; high time cost (full rollback + root-cause analysis) if it fails

---

### Option 2: Phased Upgrade Through Intermediate Chart Versions

**Description**: For components with a large version gap (specifically Traefik: 39.0.x chart -> 39.0.9 -> 40.3.0 -> 41.0.2), upgrade through intermediate minor/major chart releases, validating pod health and routing after each step before proceeding.

**Pros:**
- [o] Each step isolates a smaller schema diff, making `values.yaml` breaking changes easier to identify and fix incrementally
- [o] Natural rollback checkpoints exist at each intermediate version
- [o] Aligns with Helm/Traefik community guidance to avoid skipping major chart lines where breaking changes are documented per-release

**Cons:**
- [x] More total commands and verification cycles
- [x] Longer wall-clock time for the maintenance window

**Cost Estimate**: Higher time cost upfront; lower expected total cost when factoring in failure-recovery avoidance

---

### Option 3: Full Rebuild from Scratch (Skip Upgrade, Reinstall Everything Post-OS-Migration)

**Description**: Skip upgrading the current cluster entirely; perform the OS reinstall first, then bootstrap all components fresh at their latest versions on Ubuntu 26.04.

**Pros:**
- [o] No need to manage in-place `values.yaml` migrations at all
- [o] Guaranteed clean state

**Cons:**
- [x] Loses the opportunity to validate upgrade paths and document breaking-change diffs (`values.yaml` schema knowledge) that are directly reusable as an ADR/runbook artifact for board-level review
- [x] No etcd snapshot of a validated, upgraded configuration to use as a restoration baseline
- [x] Does not exercise or document the in-place upgrade competency that is part of the platform's operational maturity narrative

**Cost Estimate**: Comparable execution time, but negative value for documentation and demonstrable operational skill

---

## Decision Outcome

**Chosen option**: Option 2 - Phased Upgrade Through Intermediate Chart Versions (applied selectively, based on version-gap size)

**Rationale:**
- Traefik's version gap was the largest (39.x -> 41.x), so it was upgraded through three explicit checkpoints (39.0.9 -> 40.3.0 -> 41.0.2), each validated via `helm template --dry-run` schema checks and `kubectl rollout status` before proceeding
- cert-manager, GPU Operator, and JupyterHub had smaller version gaps and stable `values.yaml` schemas across the gap, so a single-step upgrade with a pre-flight `--dry-run` was sufficient and consistent with Option 1's efficiency benefit where the risk profile allowed it
- This is a hybrid application of phased strategy: phase upgrades where schema drift risk is high, single-step upgrades where it is low. This reflects the actual TCO trade-off rather than a dogmatic all-or-nothing approach
- An etcd snapshot was taken both before and after the full upgrade sequence, providing a hard rollback boundary regardless of which strategy was used per component

**Expected Benefits:**
- Documented, reproducible `values.yaml` diffs for each breaking schema change (captured in the accompanying runbook), directly reusable if the same upgrade path is encountered again post-SuperPod migration
- Reduced risk of an undiagnosable failure state going into the OS reinstall window
- Establishes a repeatable pattern: pre-flight dry-run -> apply -> verify rollout -> checkpoint, before advancing to the next version

**Accepted Trade-offs:**
- Additional wall-clock time spent on Traefik's three-step path versus a hypothetical single jump
- Manual verification steps (e.g., deleting stuck `Pending` old-ReplicaSet pods) required operator attention rather than being fully automated

---

## Consequences

### Positive
- [o] Full upgrade path is documented step-by-step with exact `values.yaml` diffs, forming a reusable runbook for future major-version jumps
- [o] Both cert-manager `Certificate`/`CertificateRequest` state and Traefik `IngressRoute` state were preserved without unplanned re-issuance or routing disruption
- [o] GPU Operator time-slicing configuration and DCGM exporter compatibility were explicitly re-verified against the new driver/CUDA baseline (610.43.02 / CUDA 13.3), protecting the SuperPod scalability narrative
- [o] Calico compatibility was explicitly audited (not upgraded) with documented rationale, avoiding unnecessary CNI churn in the same maintenance window

### Negative
- [!] Manual pod cleanup required for `ContainerStatusUnknown/Unknown` (JupyterHub) and stuck old-ReplicaSet `Pending` pods (Traefik) at each phase -> Mitigation: documented explicitly in the runbook as a known operational step, candidate for future automation via a post-upgrade cleanup script
- [!] No staging cluster means all validation was performed in a single-node production-equivalent environment -> Mitigation: etcd snapshot before/after provides the rollback safety net in lieu of a staging tier

### Neutral
- <!> Calico remains at v3.31.3, unchanged this cycle; scheduled for re-evaluation at the next quarterly review or upon the next k3s major version bump

---

## Implementation Plan

1. **Phase 1** (Pre-flight): etcd snapshot, Helm repo sync, current-version baseline capture
2. **Phase 2** (Core upgrades): cert-manager (single-step) -> Traefik (three-step phased) -> GPU Operator (single-step) -> JupyterHub (single-step)
3. **Phase 3** (Audit and cleanup): Calico compatibility audit (no upgrade), stale image pruning, final etcd snapshot

**Success Metrics:**
- All Helm releases report target chart version via `helm list -n <namespace>`
- All Deployments/DaemonSets pass `kubectl rollout status` with zero manual intervention beyond documented cleanup steps
- No unplanned TLS certificate re-issuance or ingress routing downtime observed post-upgrade

---

## References

### Internal
- [Platform Component Upgrade Runbook (2026-07)](../runbooks/2026-07-platform-component-upgrade.md)
- [ADR-016: NetworkPolicy Zero-Trust Implementation](ADR-016-network-policy-zero-trust.md)
- [ADR-009: Standalone Traefik Deployment](ADR-009-standalone-traefik-deployment.md)

### External
- [Traefik Helm Chart Releases](https://artifacthub.io/packages/helm/traefik/traefik)
- [NVIDIA GPU Operator DCGM Container Catalog](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/cloud-native/containers/dcgm/)

---

## Approval

**Decision Date**: 2026-07-20
**Approved By**: Platform Engineering
**Review Cycle**: Applied per major maintenance window (non-periodic; triggered by version-gap size)
**Next Review**: Upon next multi-version component upgrade cycle

---

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-07-20 | 1.0 | Range | Initial ADR documenting phased upgrade strategy for cert-manager, Traefik, GPU Operator, and JupyterHub |
