# my-zot

对zot chart进行简单封装，得到一个新的chart。

1. 使用S3作为zot存储后端，只需提供S3访问地址。
2. 开启pull through cache, 自动代理 ghcr/dockerhub/quay/google/k8s 仓库
3. 自带一个 clash/mihomo，只需提供订阅链接。

