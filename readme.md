# kube-registry

本仓库提供一个chart，在k8s内部署一套镜像仓库，支持clash订阅代理和pull through cache, 无需配置每个docker的registry-mirror.

**支持的上游仓库**：
- Docker Hub → `/dockerhub/*`
- GHCR → `/ghcr/*`
- Quay.io → `/quay/*`
- Kubernetes Registry → `/k8s/*`

## 工作原理

```mermaid
graph TD
    A[用户创建 Pod<br/>kubectl run nginx --image=nginx:latest] --> B[Mutating Admission Webhook<br/>拦截并重写镜像地址]
    B --> C[nginx:latest<br/>↓<br/>kube-registry:5000/dockerhub/nginx:latest]
    C --> D[Kubelet<br/>从重写后的地址拉取镜像]
    D --> E[Zot 镜像仓库服务]
    E --> F{检查 S3 缓存}
    F -->|缓存命中| G[直接返回镜像]
    F -->|缓存未命中| H[Clash 代理<br/>加速访问海外仓库]
    H --> I[上游镜像仓库<br/>ghcr.io/docker.io/quay.io/registry.k8s.io]
    I --> J[镜像存储到 S3<br/>供下次使用]
    J --> D
    G --> D
```

## 开发者文档

见 