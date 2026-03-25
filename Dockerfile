# 使用 openclaw:local 作为基础镜像（基于 Debian）
FROM openclaw:local

ENV DEBIAN_FRONTEND=noninteractive
USER root

# ================================
# 1. 安装系统依赖和工具
# ================================
RUN apt-get update || (sleep 5 && apt-get update)

# 基础工具 + Python 虚拟环境支持
RUN apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        python3-full \
        libpython3.11 \
        curl \
        git \
        xvfb \
        x11vnc \
        xfce4 \
        supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建虚拟环境并安装全局 Python 工具
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 升级 pip 并安装 pyinstaller 和 websockify（在虚拟环境中）
RUN pip install --upgrade pip && \
    pip install pyinstaller websockify

# ================================
# 2. 打包 Python 项目
# ================================
COPY agents /tmp/agents
RUN cd /tmp/agents && \
    pip install -r requirements.txt && \
    for script in agent_partition agent_optimization agent_merge; do \
        pyinstaller --onefile "$script.py"; \
        cp "./dist/${script%}" "/usr/local/bin/${script%}" ;  \
    done && \
    rm -rf /tmp/agents /root/.cache

# 将虚拟环境中的 websockify 链接到系统 PATH
RUN ln -s /opt/venv/bin/websockify /usr/local/bin/websockify

# ================================
# 3. 复制 Skills
# ================================
COPY skills /skills

# ================================
# 3. 安装 code-server
# ================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ================================
# 4. 安装 noVNC（纯静态文件，无需编译）
# ================================
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc && \
    rm -rf /opt/novnc/.git

# ================================
# 5. 创建启动脚本（用于查找 openclaw.mjs 的正确路径）
# ================================
RUN echo '#!/bin/bash\n\
OPENCLAW_PATH=$(find / -name openclaw.mjs 2>/dev/null | head -n1)\n\
if [ -z "$OPENCLAW_PATH" ]; then\n\
    echo "openclaw.mjs not found!" >&2\n\
    exit 1\n\
fi\n\
cd "$(dirname "$OPENCLAW_PATH")"\n\
exec node openclaw.mjs gateway --allow-unconfigured\n' > /start_openclaw.sh && \
    chmod +x /start_openclaw.sh

# ================================
# 6. 配置 supervisor
# ================================
RUN mkdir -p /etc/supervisor/conf.d

# 写入 supervisor 配置文件
RUN cat > /etc/supervisor/conf.d/rtl-claw.conf <<EOF
[supervisord]
nodaemon=true
logfile=/dev/null
pidfile=/run/supervisord.pid

[program:openclaw]
command=/start_openclaw.sh
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:code-server]
command=code-server --bind-addr 0.0.0.0:8080 --auth none
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:xvfb]
command=Xvfb :99 -screen 0 1024x768x24
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:xfce4]
command=startxfce4
environment=DISPLAY=:99
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:x11vnc]
command=x11vnc -display :99 -forever -nopw -rfbport 5900
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:websockify]
command=/usr/local/bin/websockify --web /opt/novnc 6080 localhost:5900
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# ================================
# 7. 暴露服务端口
# ================================
EXPOSE 18789
EXPOSE 8080
EXPOSE 6080

# ================================
# 8. 使用 supervisor 管理所有进程
# ================================
# ENTRYPOINT []
CMD ["supervisord", "-n"]