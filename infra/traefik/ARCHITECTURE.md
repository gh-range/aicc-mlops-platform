# Traefik Architecture Overview

## Traffic Flow Diagram

```mermaid
graph TB
    subgraph "External Layer"
        User[End Users]
        CF[Cloudflare Proxy<br/>Universal SSL<br/>Google Trust Services]
    end
    
    subgraph "Origin Server - llm1.mlops.work"
        subgraph "Traefik (traefik-system)"
            TE[EntryPoint: websecure<br/>Port 443 hostPort]
            TR1[IngressRoute: traefik-dashboard]
            TR2[IngressRoute: ollama-inference-api]
            TR3[IngressRoute: jupyterhub-https]
            TLS[TLS Secret<br/>mlops-work-wildcard-tls<br/>Let's Encrypt R13]
            MW1[Middleware: security-headers]
            MW2[Middleware: rate-limit]
            MW3[Middleware: dashboard-auth]
            MW4[Middleware: timeout-extended]
        end
        
        subgraph "Backend Services"
            API[api@internal<br/>Traefik Dashboard]
            OLLAMA[ollama-service:11434<br/>namespace: ollama]
            JUPYTER[proxy-public:80<br/>namespace: jupyterhub]
        end
    end
    
    subgraph "Certificate Management"
        CM[cert-manager]
        CI[ClusterIssuer<br/>letsencrypt-prod]
        CERT[Certificate<br/>mlops-work-wildcard]
    end

    User -->|HTTPS| CF
    CF -->|traefik.mlops.work<br/>Proxied| TE
    CF -.->|jupyter.mlops.work<br/>DNS Only| TE
    CF -->|ollama.mlops.work<br/>Proxied| TE
    
    TE --> TR1
    TE --> TR2
    TE --> TR3
    
    TR1 --> MW2
    MW2 --> MW1
    MW1 --> MW3
    MW3 --> API
    
    TR2 --> MW1
    MW1 --> MW4
    MW4 --> OLLAMA
    
    TR3 --> MW1
    MW1 --> JUPYTER
    
    TR1 -.->|references| TLS
    TR2 -.->|references| TLS
    TR3 -.->|references| TLS
    
    CM -->|manages| CERT
    CI -.->|used by| CERT
    CERT -->|generates| TLS
    
    style CF fill:#f96,stroke:#333
    style TE fill:#9cf,stroke:#333
    style TLS fill:#9f9,stroke:#333
    style CM fill:#ff9,stroke:#333
```

## Key Design Principles

### 1. Centralized TLS Management
- Single Certificate resource (`mlops-work-wildcard`)
- Single Secret (`mlops-work-wildcard-tls`)
- All IngressRoutes reference same Secret

### 2. Centralized Routing
- All IngressRoutes in `traefik-system` namespace
- Cross-namespace service references enabled
- Single point of visibility for all external traffic

### 3. Service-Specific Configuration
- Cloudflare Proxy disabled for JupyterHub (WebSocket stability)
- No rate-limit for JupyterHub (user interaction)
- Extended timeout for Ollama (LLM inference)

### 4. Layered Security
- TLS 1.2+ enforced (enterprise-tls-policy)
- Security headers on all routes (HSTS, X-Frame-Options)
- BasicAuth on Traefik Dashboard
- Rate limiting on administrative interfaces

## Component Inventory

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| cert-manager | cert-manager | Certificate lifecycle management |
| ClusterIssuer | cluster-scoped | Let's Encrypt ACME configuration |
| Certificate | traefik-system | Wildcard cert for *.mlops.work |
| Secret | traefik-system | TLS certificate storage |
| IngressRoute (3x) | traefik-system | Routing rules |
| Middleware (4x) | traefik-system | Traffic processing |
| TLSOption | traefik-system | TLS security policy |

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-02-05

