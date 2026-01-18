FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY server.js .

# 创建证书目录
RUN mkdir -p /webhook-certs

# Webhook 端口
EXPOSE 443

CMD ["node", "server.js"]
