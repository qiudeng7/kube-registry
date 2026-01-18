# 开发者文档

本项目内容包括: 

1. **文档**: 本项目是一个AI辅助开发项目，文档至关重要。
2. **clash-sidecar**: 镜像仓库的sidecar容器，用于代理。实现思路参考 [clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install)
3. **webhook-server**: 当apiserver收到符合某种条件的请求时(在本项目中为创建pod的请求)，会发送一个请求到我们的webhook-server，webhook-server会修改pod的镜像，改用本仓库进行代理。
4. **chart**: chart本体，把镜像仓库, clash-sidecar, webhook-server 打包成chart。
5. **github actions**: 自动化发布chart

---