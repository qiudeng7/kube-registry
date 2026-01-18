const express = require('express');
const https = require('https');
const fs = require('fs');
const app = express();

// TLS 证书配置（Kubernetes 会通过 HTTPS 调用）
const TLS_CERT = '/webhook-certs/tls.crt';
const TLS_KEY = '/webhook-certs/tls.key';

// Zot 服务地址（从环境变量读取）
const ZOT_URL = process.env.ZOT_URL || 'my-zot:5000';

// 解析请求体
app.use(express.json());

// 镜像重写规则
function rewriteImage(image) {
  // 已经是 Zot 地址，跳过
  if (image.includes(ZOT_URL)) {
    return image;
  }

  // Docker Hub 官方镜像（如 nginx:latest）
  if (!image.includes('/')) {
    return `${ZOT_URL}/dockerhub/${image}`;
  }

  // Docker Hub library 镜像（如 library/nginx）
  if (image.startsWith('library/')) {
    return `${ZOT_URL}/dockerhub/${image.replace('library/', '')}`;
  }

  // Docker Hub（如 docker.io/user/image 或 user/image）
  if (image.startsWith('docker.io/')) {
    return `${ZOT_URL}/dockerhub/${image.replace('docker.io/', '')}`;
  }

  // GHCR
  if (image.startsWith('ghcr.io/')) {
    return `${ZOT_URL}/ghcr/${image.replace('ghcr.io/', '')}`;
  }

  // Quay
  if (image.startsWith('quay.io/')) {
    return `${ZOT_URL}/quay/${image.replace('quay.io/', '')}`;
  }

  // Kubernetes Registry
  if (image.startsWith('registry.k8s.io/')) {
    return `${ZOT_URL}/k8s/${image.replace('registry.k8s.io/', '')}`;
  }

  // gcr.io
  if (image.startsWith('gcr.io/')) {
    return `${ZOT_URL}/gcr/${image.replace('gcr.io/', '')}`;
  }

  // 其他 registry，保持原样
  return image;
}

// 生成 JSON Patch
function createImagePatch(containerIndex, oldImage, newImage) {
  return {
    op: 'replace',
    path: `/spec/containers/${containerIndex}/image`,
    value: newImage
  };
}

// Mutate webhook 处理函数
function handleMutate(req) {
  const { uid, request } = req;

  if (!request || !request.object) {
    return {
      uid,
      allowed: true
    };
  }

  const pod = request.object;
  const patches = [];

  // 处理 containers
  if (pod.spec && pod.spec.containers) {
    pod.spec.containers.forEach((container, index) => {
      const oldImage = container.image;
      const newImage = rewriteImage(oldImage);

      if (oldImage !== newImage) {
        console.log(`Rewriting image: ${oldImage} -> ${newImage}`);
        patches.push(createImagePatch(index, oldImage, newImage));
      }
    });
  }

  // 处理 initContainers
  if (pod.spec && pod.spec.initContainers) {
    pod.spec.initContainers.forEach((container, index) => {
      const oldImage = container.image;
      const newImage = rewriteImage(oldImage);

      if (oldImage !== newImage) {
        // initContainers 的 path 是 /spec/initContainers/0/image
        console.log(`Rewriting initContainer image: ${oldImage} -> ${newImage}`);
        patches.push({
          op: 'replace',
          path: `/spec/initContainers/${index}/image`,
          value: newImage
        });
      }
    });
  }

  // 返回 AdmissionResponse
  const response = {
    uid,
    allowed: true,
    patchType: patches.length > 0 ? 'JSONPatch' : undefined,
    patch: patches.length > 0 ? Buffer.from(JSON.stringify(patches)).toString('base64') : undefined
  };

  return response;
}

// Webhook 端点
app.post('/mutate', (req, res) => {
  console.log('Received admission request');

  const admissionReview = req.body;
  const response = handleMutate(admissionReview);

  const admissionResponse = {
    apiVersion: 'admission.k8s.io/v1',
    kind: 'AdmissionReview',
    response: response
  };

  res.json(admissionResponse);
});

// 健康检查
app.get('/healthz', (req, res) => {
  res.status(200).send('OK');
});

// 读取 TLS 证书
const options = {
  key: fs.readFileSync(TLS_KEY),
  cert: fs.readFileSync(TLS_CERT)
};

// 启动 HTTPS 服务器
const PORT = 443;
https.createServer(options, app).listen(PORT, () => {
  console.log(`Webhook server listening on port ${PORT}`);
  console.log(`Zot URL: ${ZOT_URL}`);
});
