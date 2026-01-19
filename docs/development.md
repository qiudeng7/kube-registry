# 开发者文档

> 这是我第一次制作chart，简单做一些记录。

本项目内容包括以下部分: 
1. **文档**: 本项目是一个AI辅助开发项目，文档至关重要。
2. **clash-sidecar**: 镜像仓库的sidecar容器，用于代理。
3. **webhook-server**: 当apiserver收到符合某种条件的请求时(在本项目中为创建pod的请求)，会发送一个请求到我们的webhook-server，webhook-server会修改pod的镜像，改用本仓库进行代理。
4. **chart**: chart本体，把镜像仓库, clash-sidecar, webhook-server 打包成chart。
5. **github actions**: 自动化发布chart

## clash-sidecar

clash-sidecar 的思路参考自 [clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install)

构建阶段
1. 基于 Alpine Linux，安装 bash、curl、wget 等依赖
2. 下载 GeoIP/GeoSite 数据库、mihomo 内核、yq 工具
3. 暴露端口：7890（HTTP代理）、7891（SOCKS5）、9090（API）

运行阶段（main.sh）
1. 从 `SUBSCRIPTION_URL` 环境变量下载配置（自动处理 base64）
2. 使用 yq 将订阅配置与 mixin 配置合并（如无 mixin 则创建默认配置）
3. 启动 mihomo 内核

## 自动发布 chart

1. [helm 官方文档](https://helm.sh/zh/docs/v3/howto/chart_releaser_action/) 推荐使用 `helm/chart-releaser-action` 自动发布
2. 使用该 action 之前需要先创建一个 `gh-pages` 分支，并设置github pages从该分支进行部署 
3. 该 action 会遍历项目根目录，查询有没有符合 chart 定义的子目录(似乎是通过`Chart.yaml`进行判断)
4. 该 action 会将所有的 chart 打包成 tgz 发布到项目的 release，然后在gh-pages 分支提交一个 index.yaml 作为 helm repo 标识
5. 然后 gh-pages 分支会被部署到 pages，此时就可以通过 pages 访问 index.yaml，也就是访问helm repo，自动生成的 repo 中会引用 release 中的 tgz 压缩包


> 用的时候踩了个大坑，调试的时候出了一些异常，之前已经打包过并保存到了github actions的构建缓存，但是 release 中实际上并没有tgz，该action认为已经构建过相同版本，所以不进行工作，遇到这种情况只能删除缓存，但是缓存太多了删不完，就只能删除github仓库重开一个了。

## 其他

1. [zot 的官方 helm 包](https://github.com/project-zot/helm-charts) 看起来是一个很不错的 helm 示范。虽然内容和逻辑都不复杂，但是比较规范，甚至可以对 helm 进行单元测试，我通过这个包了解一个helm大致应该如何制作。

2. 我也尝试了解如何通过编程方法构建 chart， 唯一比较符合我需求的项目是 [cdk8s](https://github.com/cdk8s-team/cdk8s) , 但是 [这个项目](https://github.com/cdk8s/cdk8s-team-style) 让我感觉开发团队味道太冲了，下个项目再考虑吧。