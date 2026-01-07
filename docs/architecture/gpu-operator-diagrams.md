# GPU Operator Architecture Diagrams

This document contains visual representations of GPU Operator architecture for presentations and documentation.

---

## Component Relationship Diagram
```mermaid
graph TB
    subgraph "GPU Operator Namespace"
        OP[GPU Operator Controller]
        OP --> DD[Driver DaemonSet]
        OP --> TK[Toolkit DaemonSet]
        OP --> DP[Device Plugin DaemonSet]
        OP --> GFD[GPU Feature Discovery]
        OP --> DCGM[DCGM Exporter]
    end
    
    subgraph "Node/Host"
        DD --> DRIVER[NVIDIA Driver 580.x]
        TK --> RT[Container Runtime]
        DP --> KUBELET[kubelet]
        GFD --> LABELS[Node Labels]
        DCGM --> METRICS[Metrics Port 9400]
    end
    
    subgraph "Hardware"
        DRIVER --> GPU[RTX A4000 16GB]
    end
    
    subgraph "Monitoring"
        METRICS --> PROM[Prometheus]
        PROM --> GRAF[Grafana Dashboards]
    end
    
    style OP fill:#76b900
    style GPU fill:#ff6b00
    style PROM fill:#e6522c
```

---

## Deployment Flow Diagram
```mermaid
sequenceDiagram
    participant Admin
    participant Helm
    participant K8s
    participant Node
    participant GPU
    
    Admin->>Helm: helm install gpu-operator
    Helm->>K8s: Create GPU Operator resources
    K8s->>Node: Deploy Operator Pod
    K8s->>Node: Deploy DaemonSets
    
    Note over Node: Driver DaemonSet
    Node->>Node: Validate host driver 580.x
    Node->>GPU: Load kernel modules
    
    Note over Node: Toolkit DaemonSet
    Node->>Node: Install container toolkit
    Node->>Node: Configure containerd
    
    Note over Node: Device Plugin
    Node->>GPU: Query GPUs via nvidia-smi
    Node->>K8s: Register nvidia.com/gpu resource
    
    Note over Node: GPU Feature Discovery
    Node->>GPU: Query GPU properties
    Node->>K8s: Add GPU labels to node
    
    Note over Node: DCGM Exporter
    Node->>GPU: Start metrics collection
    Node->>Node: Expose :9400/metrics
    
    K8s-->>Admin: All pods Running
```

---

## GPU Time-Slicing Architecture
```mermaid
graph LR
    subgraph "Physical Hardware"
        GPU[RTX A4000<br/>16GB VRAM<br/>6144 CUDA Cores]
    end
    
    subgraph "Device Plugin Time-Slicing"
        GPU --> V1[Virtual GPU 0]
        GPU --> V2[Virtual GPU 1]
        GPU --> V3[Virtual GPU 2]
        GPU --> V4[Virtual GPU 3]
    end
    
    subgraph "User Pods"
        V1 --> POD1[JupyterHub User 1]
        V2 --> POD2[JupyterHub User 2]
        V3 --> POD3[Ollama Inference]
        V4 --> POD4[Training Job]
    end
    
    style GPU fill:#ff6b00
    style V1 fill:#76b900
    style V2 fill:#76b900
    style V3 fill:#76b900
    style V4 fill:#76b900
```

---

## Request Flow: Pod to GPU
```mermaid
graph TB
    POD[Pod requests<br/>nvidia.com/gpu: 1]
    
    POD --> SCH[Kubernetes Scheduler]
    SCH --> NODE{Node has GPU?}
    
    NODE -->|Yes| KUBELET[kubelet]
    NODE -->|No| REJECT[Pod Pending]
    
    KUBELET --> DP[Device Plugin]
    DP --> ALLOC[Allocate GPU replica]
    
    ALLOC --> RUNTIME[containerd]
    RUNTIME --> TOOLKIT[nvidia-container-toolkit]
    
    TOOLKIT --> MOUNT[Mount /dev/nvidia*]
    MOUNT --> CGROUP[Setup cgroups]
    
    CGROUP --> RUN[Container runs<br/>with GPU access]
    RUN --> DCGM[DCGM monitors<br/>GPU usage]
    
    style POD fill:#4a90e2
    style RUN fill:#76b900
    style DCGM fill:#e6522c
```

---

## Monitoring Stack Integration
```mermaid
graph LR
    subgraph "GPU Node"
        GPU[RTX A4000]
        DCGM[DCGM Exporter<br/>:9400/metrics]
        GPU --> DCGM
    end
    
    subgraph "Monitoring"
        PROM[Prometheus<br/>Scrapes every 15s]
        DCGM --> PROM
    end
    
    subgraph "Visualization"
        GRAF[Grafana]
        PROM --> GRAF
    end
    
    subgraph "Alerts"
        ALERT[AlertManager]
        PROM --> ALERT
    end
    
    subgraph "Dashboards"
        GRAF --> D1[GPU Utilization]
        GRAF --> D2[Memory Usage]
        GRAF --> D3[Temperature]
        GRAF --> D4[Power Consumption]
    end
    
    style GPU fill:#ff6b00
    style PROM fill:#e6522c
    style GRAF fill:#f46800
```

---

## Multi-Node Expansion (Future)
```mermaid
graph TB
    subgraph "Current: Single Node"
        N1[Node 1<br/>RTX A4000<br/>4 virtual GPUs]
    end
    
    subgraph "Future: 3-Node Cluster"
        N1F[Node 1<br/>RTX A4000<br/>4 virtual GPUs]
        N2[Node 2<br/>RTX A4000<br/>4 virtual GPUs]
        N3[Node 3<br/>RTX A4000<br/>4 virtual GPUs]
    end
    
    N1 -.->|Scale| N1F
    N1 -.->|Add| N2
    N1 -.->|Add| N3
    
    N1F --> TOTAL[Total: 12 virtual GPUs<br/>48GB VRAM]
    N2 --> TOTAL
    N3 --> TOTAL
    
    style N1 fill:#76b900
    style TOTAL fill:#ff6b00
```

---

## Component Lifecycle
```mermaid
stateDiagram-v2
    [*] --> Pending: helm install
    
    Pending --> DriverReady: Driver validated
    DriverReady --> ToolkitReady: Toolkit installed
    ToolkitReady --> PluginReady: Device plugin started
    PluginReady --> GFDReady: Node labeled
    GFDReady --> DCGMReady: Metrics exposed
    DCGMReady --> Running: All components healthy
    
    Running --> Updating: helm upgrade
    Updating --> Running: Update complete
    
    Running --> Failed: Component crash
    Failed --> Running: Self-healing
    
    Running --> [*]: helm uninstall
```

---

## Usage in Documentation

These diagrams are referenced in:
- Architecture design documents
- Deployment runbooks
- Team training materials
- Interview presentations
- Executive summaries

To render these diagrams:
- GitHub/GitLab automatically render Mermaid in markdown
- Use Mermaid Live Editor: https://mermaid.live
- Export as PNG/SVG for presentations
