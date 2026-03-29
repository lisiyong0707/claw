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

echo "=========================================="
echo "  UUID: $uuid"
echo "  Port: $PORT   Path: /vless"
echo "=========================================="

exec sing-box run -c /tmp/config.json
```

改完之后推送，Actions 会自动重新构建，等 3 分钟左右完成。

---

## 第二步：在 ClawCloud 创建应用

打开 [ClawCloud Run 控制台](https://console.run.claw.cloud) → **App Launchpad** → **Create App**，按下表填写：

| 项目 | 填写内容 |
|------|---------|
| App Name | `my-proxy` |
| Image Source | Public Image |
| Image Name | `ghcr.io/你的用户名/my-proxy:latest` |
| CPU | 0.1 core |
| Memory | 128 MB |
| Container Port | `2777` |
| Public Access | 开启 |

然后在 **Environment Variables** 里加一条：

| Key | Value |
|-----|-------|
| `uuid` | 你的固定 UUID |

UUID 可以在终端用 `uuidgen` 生成，也可以去 [uuidgenerator.net](https://www.uuidgenerator.net) 在线生成一个，记下来备用。

点击 **Deploy**，等状态变为 **Running**（约 1 分钟）。

---

## 第三步：拿到公网地址

部署成功后，ClawCloud 会分配一个地址，格式大概是：
```
https://xxxxxxxxxxxx.run.claw.cloud
```

在应用详情页的 **Network** 或 **Public Address** 里可以找到。

---

## 第四步：Cloudflare 绑定自己的域名（可选）

如果你想用自己的域名（比如 `proxy.example.com`），登录 Cloudflare → 选你的域名 → **DNS** → **Add record**：

| Type | Name | Target | Proxy |
|------|------|--------|-------|
| CNAME | `proxy` | `xxxxxxxxxxxx.run.claw.cloud` | 开启橙云 ✓ |

开启橙云后流量会先过 Cloudflare，服务器真实地址不会暴露给客户端，1~3 分钟内生效。

---

## 第五步：组装 VLESS 链接，导入客户端

按下面的格式拼接，把括号里的内容换成你自己的：
```
vless://你的UUID@你的域名:443?encryption=none&security=tls&sni=你的域名&type=ws&path=%2Fvless#ClawCloud
```

举个例子，用自定义域名时：
```
vless://a3f1c2d4-1234-5678-abcd-ef0123456789@proxy.example.com:443?encryption=none&security=tls&sni=proxy.example.com&type=ws&path=%2Fvless#ClawCloud
