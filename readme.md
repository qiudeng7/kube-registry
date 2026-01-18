# my-zot

对 zot chart 进行简单封装，得到一个新的chart。

1. 使用S3作为zot存储后端，只需提供S3访问地址。
2. 开启pull through cache, 自动代理 ghcr/dockerhub/quay/google/k8s 仓库
3. 自带一个 clash/mihomo，只需提供订阅链接。

## 快速开始

### 安装方式1：使用命令行参数（推荐用于测试）

```bash
helm install my-zot . \
  --set s3.region=us-east-1 \
  --set s3.bucket=my-zot-bucket \
  --set s3Credentials.accessKeyId=AKIAIOSFODNN7EXAMPLE \
  --set s3Credentials.secretAccessKey=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
  # 可选：启用 Clash 代理
  # --set clash.enabled=true \
  # --set clash.subscriptionUrl=https://your-clash-subscription-url
```

### 安装方式2：使用自定义 values 文件（推荐用于生产）

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