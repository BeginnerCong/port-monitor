#!/bin/bash

# 配置变量
VENV_DIR="port-monitor-venv"
REQUIREMENTS_FILE="backend/requirements.txt"
LOG_FILE="backend/server.log"
PORT=8000
PID_FILE="backend/server.pid"

# Linux环境虚拟环境激活路径
VENV_ACTIVATE="$VENV_DIR/bin/activate"

# 打印带时间戳的日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 检查脚本执行权限
check_permissions() {
    if [ ! -x "$0" ]; then
        chmod +x "$0" || { echo "无法添加执行权限"; exit 1; }
    fi
}

# 创建并激活虚拟环境
# 返回值: 0表示虚拟环境已存在，1表示新创建的虚拟环境
create_and_activate_venv() {
    local venv_status=0  # 默认为已存在
    
    # 检查虚拟环境是否存在
    if [ ! -d "$VENV_DIR" ]; then
        log "创建Python虚拟环境: $VENV_DIR"
        python -m venv $VENV_DIR
        if [ $? -ne 0 ]; then
            log "创建虚拟环境失败，请确保已安装Python 3.8或更高版本"
            exit 1
        fi
        venv_status=1  # 新创建的虚拟环境
    else
        log "虚拟环境已存在: $VENV_DIR"
    fi
    
    # 激活虚拟环境
    log "激活虚拟环境..."
    source $VENV_ACTIVATE
    
    # 返回虚拟环境状态
    return $venv_status
}

# 检查pip版本并在必要时升级
check_and_upgrade_pip() {
    log "检查pip版本..."
    
    # 获取当前pip版本号并解析主要版本号
    CURRENT_PIP_VERSION=$($VENV_DIR/bin/python -m pip --version 2>&1 | grep -oP 'pip \K\d+\.\d+\.\d+')
    CURRENT_MAJOR_VERSION=$(echo $CURRENT_PIP_VERSION | cut -d'.' -f1)
    
    # 定义最低要求的pip主版本号（根据警告信息中的最新版本25.2，设置一个合理的阈值）
    MIN_REQUIRED_MAJOR=23
    
    # 通过版本号比较来判断是否需要升级
    if [ -n "$CURRENT_MAJOR_VERSION" ] && [ "$CURRENT_MAJOR_VERSION" -lt "$MIN_REQUIRED_MAJOR" ]; then
        log "检测到pip版本较旧($CURRENT_PIP_VERSION)，低于要求的主版本号($MIN_REQUIRED_MAJOR)，正在升级..."
        $VENV_DIR/bin/python -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple
        log "pip升级完成"
    else
        log "pip版本满足要求($CURRENT_PIP_VERSION)，无需升级"
    fi
}

# 安装依赖项
install_dependencies() {
    log "安装依赖项..."
    
    # 检查pip版本并在出现警告时才升级
    check_and_upgrade_pip
    
    # 然后安装项目依赖
    pip install -r $REQUIREMENTS_FILE -i https://pypi.tuna.tsinghua.edu.cn/simple
    if [ $? -ne 0 ]; then
        log "安装依赖项失败"
        exit 1
    fi
}

# 启动后端服务
start_server() {
    # 创建日志目录（如果不存在）
    LOG_DIR=$(dirname $LOG_FILE)
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p $LOG_DIR
    fi
    
    # 清除旧日志文件
    log "清除旧日志文件..."
    if [ -f "$LOG_FILE" ]; then
        rm -f $LOG_FILE
    fi
    
    # 启动后端服务并将日志重定向到文件
    log "启动后端服务（端口: $PORT）..."
    log "服务将以后台方式运行，日志将保存到: $LOG_FILE"
    
    # 启动服务并将输出重定向到日志文件
    cd backend
    nohup uvicorn main:app --host 0.0.0.0 --port $PORT > "../$LOG_FILE" 2>&1 &
    
    # 获取进程ID
    SERVER_PID=$!
    
    # 将进程ID写入缓存文件
    echo $SERVER_PID > "../$PID_FILE"
    log "服务已启动，进程ID: $SERVER_PID 已保存到 $PID_FILE"
    log "可以使用 './start-venv.sh stop' 命令停止服务"
    log "查看日志：tail -f ./$LOG_FILE"
}

# 检查服务是否正在运行
# 返回值: 0表示服务正在运行，1表示服务未运行
is_server_running() {
    if [ -f "$PID_FILE" ]; then
        SERVER_PID=$(cat $PID_FILE)
        if [ -n "$SERVER_PID" ] && kill -0 $SERVER_PID 2>/dev/null; then
            return 0  # 服务正在运行
        fi
        # 清理无效的PID文件
        rm -f $PID_FILE
    fi
    return 1  # 服务未运行
}

# 退出虚拟环境并删除日志
stop_server() {
    log "==========停止服务并清理环境=========="
    
    # 从缓存文件读取进程ID
    if [ -f "$PID_FILE" ]; then
        SERVER_PID=$(cat $PID_FILE)
        if [ -n "$SERVER_PID" ]; then
            log "从缓存文件读取进程ID: $SERVER_PID"
            log "停止后端服务进程: $SERVER_PID"
            kill $SERVER_PID
            if [ $? -eq 0 ]; then
                log "后端服务已停止"
            else
                log "停止后端服务失败，请确认进程ID是否有效"
            fi
            # 删除PID文件
            rm -f $PID_FILE
            log "已删除进程缓存文件: $PID_FILE"
        else
            log "缓存文件中的进程ID为空"
            rm -f $PID_FILE
        fi
    else
        log "未找到进程缓存文件: $PID_FILE，可能服务未通过此脚本启动或已停止"
    fi
    
    # 删除日志文件
    if [ -f "$LOG_FILE" ]; then
        log "删除日志文件: $LOG_FILE"
        rm -f $LOG_FILE
    fi
    
    log "服务已停止并清理完成"
}

# 显示帮助信息
show_help() {
    echo "端口监控应用虚拟环境管理工具"
    echo "用法: $0 <command> [options]"
    echo ""
    echo "命令列表:" 
    echo "  start          启动应用（创建/激活虚拟环境并启动服务，如果服务已启动则跳过）"
    echo "  stop           停止应用（停止服务并删除日志）"
    echo "  restart        重启应用（先停止服务，然后重新启动）"
    echo "  help           显示此帮助信息"
    echo ""
    echo "选项:" 
    echo "  --force-install 强制重新安装所有依赖项（可与start命令一起使用）"
    echo ""
    echo "示例:" 
    echo "  $0 start                    # 启动服务（虚拟环境存在时跳过依赖安装）"
    echo "  $0 start --force-install    # 启动服务并强制重新安装所有依赖"
    echo "  $0 restart                  # 重启服务"
}

# 主函数
main() {
    check_permissions
    
    case "$1" in
        start)
            # 检查服务是否已在运行
            if is_server_running; then
                log "服务已在运行中，跳过启动过程"
                log "如需重启服务，请使用 './start-venv.sh restart' 命令"
                log "如需停止服务，请使用 './start-venv.sh stop' 命令"
                exit 0
            fi
            
            # 检查是否有--force-install参数
            local force_install=0
            if [ "$2" = "--force-install" ]; then
                force_install=1
            fi
            
            create_and_activate_venv
            # 检查虚拟环境是否是新创建的（返回值1表示新创建）或是否强制安装
            if [ $? -eq 1 ] || [ $force_install -eq 1 ]; then
                if [ $force_install -eq 1 ]; then
                    log "强制重新安装依赖项..."
                else
                    log "新创建的虚拟环境，开始安装依赖项..."
                fi
                install_dependencies
            else
                log "虚拟环境已存在，跳过依赖项安装（如需重新安装，请使用 --force-install 参数）"
            fi
            start_server
            ;;
        stop)
            stop_server
            ;;
        restart)
            log "==========重启服务=========="
            # 先停止服务
            stop_server
            
            # 等待一段时间确保服务完全停止
            log "等待服务完全停止..."
            sleep 2
            
            # 然后启动服务
            log "开始重新启动服务..."
            create_and_activate_venv
            start_server
            log "服务已成功重启"
            ;;
        help | *)
            show_help
            ;;
    esac
}

main "$@"
trap 'echo "脚本中断"; exit 1' INT TERM