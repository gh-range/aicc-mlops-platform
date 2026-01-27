# ADR-012: Selection of Traefik IngressRoute CRD over Standard Ingress API

## Status
Proposed (2026-01-27)

## Context
As the AICC MLOps platform scales from a single-node MAV (Micro-Architecture Validation) to NVIDIA B200 SuperPods, the complexity of traffic management increases significantly. We require a robust mechanism to handle advanced routing, integrated security middlewares, and specialized AI workload requirements (such as model mirroring and weighted canary deployments).

The standard Kubernetes Ingress API relies heavily on vendor-specific annotations, which are:
1. Difficult to validate via standard schemas.
2. Prone to syntax errors in large-scale YAML manifests.
3. Limited in expressing complex routing logic (e.g., TCP/UDP, weighted traffic).

## Decision
We will exclusively use **Traefik IngressRoute (Custom Resource Definition)** as the primary ingress management mechanism for all infrastructure and application services.

## Rationale
- **Native CRD Validation**: IngressRoute provides strong typing and schema validation, enabling CI/CD pipelines to catch configuration errors before deployment to the MAV node.
- **Middleware Orchestration**: Allows clean, reusable chaining of Security Middlewares (Rate Limiting, BasicAuth, HSTS) without polluting route definitions with complex annotations.
- **AI-Specific Traffic Patterns**: Supports `TrafficMirroring` for zero-impact testing of new LLM versions and `WeightedRoundRobin` for seamless canary releases of inference endpoints.
- **Observability**: Native integration with Prometheus metrics at the router and service level, facilitating deep-dive analysis in Zabbix/Grafana.

## Consequences
- **Vendor Lock-in**: Routing manifests will be specific to Traefik. However, given Traefik's status as the core ingress engine for our SuperPod architecture, this risk is mitigated by its performance and feature set.
- **Learning Curve**: Developers must familiarize themselves with Traefik-specific CRD syntax instead of standard Ingress. This will be addressed by providing standardized templates in the `/infra/templates` directory.
- **Interoperability**: Standard Ingress-based tools (like some automated SSL issuers) may require specific Traefik annotations or manual configuration of IngressRoutes.

## Compliance Mapping
- **ISO 27001**: Aligns with A.12.1.1 (Operational procedures) by ensuring structured and validated configuration changes.
- **SOC2**: Provides a clear audit trail of routing logic through declarative CRD manifests
