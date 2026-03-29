

## 第二步：在 ClawCloud 创建应用

打开 [ClawCloud Run 控制台](https://console.run.claw.cloud)，点 App Launchpad → Create App，填写如下内容：

App Name 填 `my-proxy`，Image Source 选 Public Image，Image Name 填 `ghcr.io/你的用户名/my-proxy:latest`，CPU 设 0.1 core，Memory 设 128MB，Container Port 填 `2777`，Public Access 开启。

然后在 Environment Variables 里加一条，Key 填 `uuid`，Value 填你的固定 UUID。
填完后点 Deploy，等状态变为 Running，大约 1 分钟。

---

## 第三步：拿到公网地址

部署成功后，在应用详情页的 Network 或 Public Address 里会有一个 ClawCloud 分配的地址，格式类似：
```
https://xxxxxxxxxxxx.run.claw.cloud
```

记下这个地址，后面要用。



## 第四步：Cloudflare 绑定自己的域名（可选）

如果你有自己的域名（比如 `example.com` 已经托管在 Cloudflare），登录 Cloudflare，进入该域名的 DNS 设置，添加一条 CNAME 记录：Name 填 `proxy`，Target 填上一步拿到的 `xxxxxxxxxxxx.run.claw.cloud`，Proxy 状态开启橙云。

开启橙云后流量先经过 Cloudflare，服务器真实地址不会暴露给客户端，1~3 分钟内生效。

## 第五步：拼接 VLESS 链接，导入客户端

用 ClawCloud 自带地址时，链接格式如下（把 `xxxx` 和 UUID 换成你自己的）：
```
vless://你的UUID@xxxxxxxxxxxx.run.claw.cloud:443?encryption=none&security=tls&sni=xxxxxxxxxxxx.run.claw.cloud&type=ws&path=%2Fvless#ClawCloud
```

用 Cloudflare 自定义域名时：
```
vless://你的UUID@proxy.example.com:443?encryption=none&security=tls&sni=proxy.example.com&type=ws&path=%2Fvless#ClawCloud
