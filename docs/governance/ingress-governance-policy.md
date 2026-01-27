# Ingress and Traffic Governance Policy

## 1. Purpose
This policy defines the standards for implementing ingress resources and traffic routing within the AICC MLOps Platform. It ensures operational consistency, security compliance, and multi-tenant isolation as the platform scales from MAV nodes to NVIDIA SuperPods.

## 2. Naming Conventions
To prevent resource collisions and improve auditability, all Ingress-related resources must follow these naming patterns:

- **IngressRoute**: `<service-name>-ingressroute` (e.g., `ollama-api-ingressroute`)
- **Middleware**: `<policy-type>-<scope>` (e.g., `rate-limit-global`, `auth-internal-only`)
- **TLSOption**: `tls-modern-policy`

## 3. Mandatory Labeling
All manifests must include the following metadata labels for inventory management and automated scanning:
- `app.kubernetes.io/part-of: aicc-mlops-platform`
- `aicc.mlops/tenant: <department-name>`
- `aicc.mlops/security-tier: <1|2|3>` (1 = Public, 3 = Restricted)

## 4. Multi-tenancy & Isolation
- **Namespace Residency**: Infrastructure ingress resources (Traefik/Cert-manager) MUST reside in `traefik-system`. Application-specific routes must reside in the application's own namespace.
- **Cross-Namespace Forbidden**: IngressRoutes must not reference Secrets or Middlewares in other namespaces unless explicitly authorized via a `ReferenceGrant` (Gateway API context).

## 5. Security Requirements
- **TLS Everywhere**: All IngressRoutes MUST use `websecure` (HTTPS) entrypoints. Plain HTTP is restricted to global redirection only.
- **Mandatory Middlewares**: 
  - All public-facing endpoints MUST attach a `rate-limit` middleware.
  - Management dashboards MUST attach a `basic-auth` (or higher) middleware.
- **Header Hardening**: Use the `security-headers` middleware to enforce HSTS and prevent Clickjacking.

## 6. Compliance Alignment
- **ISO 27001**: Supports Control A.13.1.1 (Network controls) by enforcing structured access paths.
- **GDPR**: Ensures data in transit is encrypted using approved TLS 1.3 ciphers.
