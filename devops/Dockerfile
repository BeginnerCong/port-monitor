FROM python:3.10-slim

# 设置工作目录
WORKDIR /app/backend

# 使用国内镜像源
RUN echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free" > /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*

# 复制后端代码
COPY ./backend /app/backend

# 安装依赖
RUN pip install --no-cache-dir -r /app/backend/requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制前端静态文件
COPY ./frontend /app/frontend

# 暴露端口
EXPOSE 8000

# 设置环境变量
ENV IN_DOCKER=true
# 设置PYTHONPATH，确保Python能找到backend模块
ENV PYTHONPATH=/app

# 启动 FastAPI 后端，使用环境变量标记Docker运行模式
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]