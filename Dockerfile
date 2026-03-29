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
