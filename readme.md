# k8s-selfhost-repo

k8s自托管仓库，支持clash代理和pull through cache，用户只需要设置订阅链接和对象存储，部署过本仓库之后，集群内的所有镜像拉取都会先检查对象存储中有没有缓存，如果没有缓存就用clash代理，不需要对每个节点的docker都进行配置。

## 工作原理

```mermaid
graph TD
    A[用户创建 Pod<br/>kubectl run nginx --image=nginx:latest] --> B[Mutating Admission Webhook<br/>拦截并重写镜像地址]
    B --> C[nginx:latest<br/>↓<br/>k8s-selfhost-repo:5000/dockerhub/nginx:latest]
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

## 快速开始

### 安装方式1：从 GHCR 安装（推荐）

```bash
helm install my-repo oci://ghcr.io/qiudeng7/charts/k8s-selfhost-repo \
  --set s3.region=us-east-1 \
  --set s3.bucket=my-zot-bucket \
  --set s3Credentials.accessKeyId=AKIAIOSFODNN7EXAMPLE \
  --set s3Credentials.secretAccessKey=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### 安装方式2：从源码安装

```bash
helm install my-repo . \
  --set s3.region=us-east-1 \
  --set s3.bucket=my-zot-bucket \
  --set s3Credentials.accessKeyId=AKIAIOSFODNN7EXAMPLE \
  --set s3Credentials.secretAccessKey=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
  # 可选：启用 Clash 代理
  # --set clash.enabled=true \
  # --set clash.subscriptionUrl=https://your-clash-subscription-url
  # 可选：启用自动镜像重写 Webhook
  # --set webhook.enabled=true
```

### 安装方式3：使用自定义 values 文件（推荐用于生产）

1. 复制并编辑 values 文件：

```bash
cp values.yaml my-values.yaml
```

2. 编辑 `my-values.yaml`，填写配置：

```yaml
s3:
  region: "us-east-1"           # 你的 S3 区域
  bucket: "my-zot-bucket"       # 你的 S3 存储桶名称
  regionEndpoint: ""            # 可选：MinIO 等自定义 endpoint

s3Credentials:
  accessKeyId: "AKIAIOSFODNN7EXAMPLE"      # AWS_ACCESS_KEY_ID
  secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # AWS_SECRET_ACCESS_KEY

# 可选：启用 Clash 代理
clash:
  enabled: true
  subscriptionUrl: "https://your-clash-subscription-url"

# 可选：启用自动镜像重写 Webhook
webhook:
  enabled: true
```

3. 使用自定义 values 安装：

```bash
helm install my-zot . -f my-values.yaml
```


安装后，chart 会自动创建：

- **ConfigMap** `my-zot-config`：包含 S3 配置（region、bucket）
- **Secret** `my-zot-secret`：包含 AWS 凭证（accessKeyId、secretAccessKey）
- **Zot 部署**：自动挂载上述 ConfigMap 和 Secret

### 验证安装

```bash
# 查看 Pod 状态
kubectl get pods -l app.kubernetes.io/name=zot

# 查看 S3 配置
kubectl get configmap my-zot-config -o yaml

# 获取访问地址
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
export NODE_PORT=$(kubectl get svc my-zot -o jsonpath='{.spec.ports[0].nodePort}')
echo "访问地址: http://${NODE_IP}:${NODE_PORT}"
```

### 配置 Docker 客户端

安装完成后，配置 Docker 使用 Zot 的 pull through cache：

#### 方式1：配置 /etc/docker/daemon.json（推荐）

编辑 `/etc/docker/daemon.json`：

```json
{
  "registry-mirrors": [
    "http://<NODE_IP>:<NODE_PORT>"
  ]
}
```

重启 Docker：

```bash
sudo systemctl restart docker
```

现在拉取镜像时会自动使用 Zot 缓存：

```bash
# Docker 会自动从 Zot 拉取（如果已缓存）
docker pull nginx:latest
docker pull postgres:14
```

#### 方式2：手动指定 Zot 地址

拉取时使用完整路径：

```bash
# Docker Hub 镜像
docker pull <NODE_IP>:<NODE_PORT>/dockerhub/nginx:latest

# GitHub Container Registry
docker pull <NODE_IP>:<NODE_PORT>/ghcr/example/app:v1.0

# Quay.io
docker pull <NODE_IP>:<NODE_PORT>/quayio/prometheus/prometheus:latest

# Kubernetes Registry
docker pull <NODE_IP>:<NODE_PORT>/k8s/kube-apiserver:v1.28.0
```

**支持的上游仓库**：
- Docker Hub → `/dockerhub/*`
- GHCR → `/ghcr/*`
- Quay.io → `/quay/*`
- Kubernetes Registry → `/k8s/*`