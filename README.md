# VLESS + WebSocket 代理部署指南

基于 sing-box 的 VLESS + WebSocket 代理服务，通过 GitHub Actions 自动构建镜像并部署到 ClawCloud，支持 Cloudflare 自定义域名。

---

## 项目结构

```
my-proxy/
├── Dockerfile
├── entrypoint.sh
└── .github/
    └── workflows/
        └── build.yml
```

---

## 工作原理

```
客户端 → Cloudflare（TLS + 隐藏真实 IP）→ ClawCloud（公网暴露）→ sing-box（VLESS + WS）→ 目标网站
```

- **GitHub Actions** 负责自动构建多架构（amd64 / arm64）Docker 镜像并推送到 ghcr.io
- **ClawCloud** 负责运行容器、提供公网地址和 HTTPS
- **Cloudflare** 负责自定义域名和隐藏服务器真实 IP（可选）
- **sing-box** 在容器内监听 2777 端口，处理 VLESS + WebSocket 流量

---

## 文件内容

### Dockerfile

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    curl wget jq uuid-runtime ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then SB_ARCH="amd64"; \
    elif [ "$ARCH" = "aarch64" ]; then SB_ARCH="arm64"; fi && \
    VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
      | jq -r '.tag_name' | sed 's/v//') && \
    wget -qO /tmp/sb.tar.gz \
      "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${SB_ARCH}.tar.gz" && \
    tar -xzf /tmp/sb.tar.gz -C /tmp && \
    mv /tmp/sing-box-*/sing-box /usr/local/bin/sing-box && \
    chmod +x /usr/local/bin/sing-box && \
    rm -rf /tmp/sing-box*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2777
ENTRYPOINT ["/entrypoint.sh"]
```

### entrypoint.sh

```bash
#!/bin/bash
set -e

PORT=2777

if [ -z "$uuid" ]; then
    uuid=$(uuidgen)
fi

cat > /tmp/config.json <<EOF
{
  "inbounds": [{
    "type": "vless",
    "listen": "0.0.0.0",
    "listen_port": $PORT,
    "users": [{"uuid": "$uuid", "flow": ""}],
    "transport": { "type": "ws", "path": "/vless" }
  }],
  "outbounds": [{"type": "direct"}]
}
EOF

echo "UUID: $uuid  Port: $PORT  Path: /vless"

exec sing-box run -c /tmp/config.json
```

### .github/workflows/build.yml

```yaml
name: Build and Push

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: 登录 ghcr.io
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: 设置多架构构建
        uses: docker/setup-qemu-action@v3

      - uses: docker/setup-buildx-action@v3

      - name: 构建并推送
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}
```

---

## 部署步骤

### 第一步：推送代码到 GitHub

```bash
git init
git add .
git commit -m "init"
git remote add origin https://github.com/你的用户名/my-proxy.git
git push -u origin main
```

推送后 GitHub Actions 自动构建，约 3~5 分钟完成。进入仓库 Actions 标签页可查看进度。

构建完成后镜像地址为：

```
ghcr.io/你的用户名/my-proxy:latest
```

### 第二步：设置镜像为公开

仓库页面 → Packages → 找到 `my-proxy` → Package settings → Change visibility → Public

> 不设为公开，ClawCloud 拉取时会报 403 Forbidden 错误。

同时确认仓库 Settings → Actions → General → Workflow permissions 已选择 **Read and write permissions**，否则构建推送会报 permission_denied 错误。

### 第三步：在 ClawCloud 创建应用

打开 [ClawCloud Run 控制台](https://console.run.claw.cloud)，点 App Launchpad → Create App，填写如下内容：

| 项目 | 填写内容 |
|------|---------|
| App Name | 自定义，如 `Claw-0609-USW` |
| Image Source | Public Image |
| Image Name | `ghcr.io/你的用户名/my-proxy:latest` |
| CPU | 0.1 Core |
| Memory | 128 Mi |
| Container Port | `2777` |
| Public Access | 开启 |

在 Environment Variables 里添加：

| Key | Value |
|-----|-------|
| `uuid` | 你的固定 UUID（用 `uuidgen` 生成） |

点 Deploy，等状态变为 Running（约 1 分钟）。

### 第四步：获取公网地址

部署成功后，在应用详情页 Network 里找到公网地址，格式如：

```
https://xxxxxxxxxxxx.us-west-1.clawcloudrun.com
```

### 第五步：Cloudflare 绑定自定义域名（可选）

登录 Cloudflare，进入域名 DNS 设置，添加一条 CNAME 记录：

| Type | Name | Target | Proxy |
|------|------|--------|-------|
| CNAME | `proxy` | `xxxxxxxxxxxx.us-west-1.clawcloudrun.com` | 开启橙云 |

开启橙云后服务器真实 IP 不会暴露，1~3 分钟内生效。

---

## 生成 VLESS 链接

部署完成后，按以下格式拼接链接（从容器日志可以找到 UUID）：

**使用 ClawCloud 自带地址：**

```
vless://你的UUID@xxxxxxxxxxxx.us-west-1.clawcloudrun.com:443?encryption=none&security=tls&sni=xxxxxxxxxxxx.us-west-1.clawcloudrun.com&type=ws&path=%2Fvless#ClawCloud
```

**使用 Cloudflare 自定义域名：**

```
vless://你的UUID@proxy.example.com:443?encryption=none&security=tls&sni=proxy.example.com&type=ws&path=%2Fvless#ClawCloud
```

复制链接后，在 v2rayN、Clash、sing-box 等客户端选择「从剪贴板导入」即可。

---

## 常见问题

**构建推送报 permission_denied**

进入仓库 Settings → Actions → General → Workflow permissions，选 Read and write permissions 后保存，重新触发构建。

**ClawCloud 拉取镜像报 403 Forbidden**

镜像未设为公开。进入 GitHub Packages → my-proxy → Package settings → Change visibility → Public。

**日志里出现 bad path: /**

这是 ClawCloud 健康检查探测根路径产生的，不影响正常使用，忽略即可。

**公网地址显示 Pending**

正常现象，等待 1~3 分钟后刷新页面即可。

---

## 注意事项

- ClawCloud 应用名称创建后不支持修改，命名前确认好格式
- UUID 建议固定，容器重启后节点信息不会改变
- 定期执行 `docker pull` 或触发 Actions 重新构建以获取最新 sing-box 版本
