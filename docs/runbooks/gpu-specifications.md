# GPU Hardware Specifications

## Detection Date
$(date '+%Y-%m-%d %H:%M:%S')

## GPU Information
```
$(nvidia-smi --query-gpu=index,name,driver_version,memory.total,compute_cap,pci.bus_id --format=csv)
```

## Detailed Output
```
$(nvidia-smi)
```

## CUDA Version
```
$(nvcc --version 2>/dev/null || echo "nvcc not in PATH")
```

## Verification
- [x] GPU detected by nvidia-smi
- [x] Driver loaded successfully
- [x] Memory accessible
- [x] Ready for k3s GPU Operator

