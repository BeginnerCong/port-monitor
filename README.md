# Linux服务器端口监控工具

## 项目介绍

这是一个轻量级的Linux服务器端口监控工具，可以实时显示服务器上所有开放端口及其相关信息，包括协议类型、状态、占用进程和用户等。工具采用前后端分离架构：

- **后端**：使用FastAPI框架开发，提供RESTful API接口获取服务器IP和端口信息
- **前端**：基于HTML、Tailwind CSS和Chart.js构建，提供直观的可视化界面

工具特点：
- 支持Docker容器和Python虚拟环境两种部署方式
- 兼容在Docker容器内运行时获取宿主机的端口信息
- 提供实时监控和刷新功能
- 响应式设计，支持不同设备访问

## 系统架构

```
├── backend/             # 后端代码目录
│   ├── main.py          # FastAPI主程序
│   ├── requirements.txt # Python依赖项
├── frontend/            # 前端代码目录
│   ├── index.html       # 主页面
│   ├── css/             # 样式文件
│   ├── js/              # JavaScript文件
│   └── fonts/           # 字体文件
├── devops/              # 部署相关文件
│   └── Dockerfile       # Docker构建文件
├── docker-compose.yaml  # Docker Compose配置文件
├── start-docker.sh      # Docker部署管理脚本
└── start-venv.sh        # Python虚拟环境启动脚本
```

## 部署方式

### 方式一：Docker容器部署

使用项目提供的`start-docker.sh`脚本可以方便地管理应用的生命周期，这是推荐的部署方式，特别适合在生产环境使用。

#### 前提条件
- 安装Docker和Docker Compose
- 确保当前用户有足够权限运行Docker命令

#### 部署步骤

1. 克隆或下载项目代码到本地服务器

2. 进入项目根目录

```bash
cd /path/to/port-monitor
```

3. 使用`start-docker.sh`脚本启动服务

```bash
./start-docker.sh
```

4. 访问监控界面

打开浏览器，访问 `http://服务器IP:8000` 即可查看端口监控界面。

#### 应用管理命令

项目提供了`start-docker.sh`脚本，支持以下命令：

```bash
./start-docker.sh start          # 启动应用
./start-docker.sh stop           # 停止应用
./start-docker.sh restart        # 重启应用
./start-docker.sh build        # 执行docker构建并打包应用
./start-docker.sh build-restart # 执行docker构建并重启应用
./start-docker.sh help           # 显示帮助信息
```

### 方式二：Python虚拟环境部署

如果不想使用Docker，可以直接在Python虚拟环境中运行后端服务。

#### 前提条件
- 安装Python 3.8或更高版本
- 确保系统已安装`ss`命令（通常在`iproute2`包中）

#### 部署步骤

使用提供的`start-venv.sh`脚本可以方便地在Python虚拟环境中管理后端服务。该脚本支持命令行参数，包括start、stop和restart命令：

1. 克隆或下载项目代码到本地服务器

2. 进入项目根目录

```bash
cd /path/to/port-monitor
```

3. 为脚本添加执行权限

```bash
chmod +x start-venv.sh
```

4. 运行脚本启动服务

```bash
./start-venv.sh start
```

**可选参数：**
- `--force-install`：强制重新安装所有依赖项，即使虚拟环境已存在。当requirements.txt文件更新或需要刷新依赖时使用此参数。

**使用示例：**
```bash
# 常规启动（虚拟环境存在时跳过依赖安装）
./start-venv.sh start

# 强制重新安装依赖项并启动
./start-venv.sh start --force-install

# 停止服务
./start-venv.sh stop

# 重启服务
./start-venv.sh restart
```

#### 停止服务

可以使用脚本的stop命令来停止服务并清理环境：

```bash
./start-venv.sh stop
```

#### 重启服务

可以使用脚本的restart命令来重启服务：

```bash
./start-venv.sh restart
```

重启服务会先停止当前运行的服务，然后重新启动，适用于需要刷新服务状态或应用配置变更的场景。

### 注意事项

1. 虚拟环境部署方式不支持使用`start-docker.sh`脚本，需要使用提供的`start-venv.sh`脚本
2. 此脚本仅支持Linux环境，部分功能（如端口和进程信息获取）在Windows系统上可能无法正常工作
3. 停止服务时，脚本只会使用缓存文件中的进程ID，不会通过其他方式查找进程。如果缓存文件丢失或无效，可能无法正常停止服务

## 使用说明

### 功能特性

1. **服务器信息显示**：顶部导航栏显示服务器IP地址和运行状态
2. **端口列表**：显示所有TCP/UDP端口的详细信息，包括：
   - 端口号和协议类型
   - 连接状态（LISTEN、ESTABLISHED等）
   - 本地和远程地址
   - 占用端口的进程名称和PID
   - 进程所属用户
3. **刷新功能**：点击刷新按钮可以实时更新端口信息
4. **测试功能**：开发环境下可测试在线/离线状态显示

### 注意事项

1. 该工具需要足够的权限来获取端口和进程信息
2. 在Docker容器中运行时，需要挂载宿主机的`/proc`目录并使用特权模式
3. 为了确保能正确获取所有端口信息，建议以root用户或有sudo权限的用户运行
4. 浏览器支持：推荐使用Chrome、Firefox、Edge等现代浏览器

## 开发说明

如果您想参与项目开发，可以按照以下步骤进行：

1. 克隆项目代码
2. 安装开发依赖
3. 进行代码修改
4. 测试功能是否正常
5. 提交代码变更

## License

MIT License

## 致谢

感谢所有为该项目做出贡献的开发者和用户！