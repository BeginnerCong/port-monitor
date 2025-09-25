#!/bin/bash

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

# 检查docker-compose文件是否存在
define_compose_file() {
    if [ -f "docker-compose.yaml" ]; then
        COMPOSE_FILE="docker-compose.yaml"
    elif [ -f "docker-compose.yml" ]; then
        COMPOSE_FILE="docker-compose.yml"
    else
        echo "错误：未找到docker-compose.yaml或docker-compose.yml文件" >&2
        return 1
    fi
    return 0
}

# 停止并删除容器
stop_containers() {
    log "==========停止应用=========="
    if ! define_compose_file; then
        exit 1
    fi
    docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1
    log "应用已停止"
}

# 启动容器
start_containers() {
    log "==========启动应用=========="
    if ! define_compose_file; then
        exit 1
    fi
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate || { echo "容器启动失败"; exit 1; }
    log "应用已启动"
}

# 构建镜像
build_image() {
    log "==========构建镜像=========="
    if ! define_compose_file; then
        exit 1
    fi
    
    # 构建前 snapshot
    local before_dangling=$(docker images -f "dangling=true" -q)
    
    docker compose -f "$COMPOSE_FILE" build || { echo "镜像构建失败"; exit 1; }
    log "Docker 镜像构建成功"
    
    # 清理本次构建产生的 <none> 镜像
    local after_dangling=$(docker images -f "dangling=true" -q)
    local new_dangling=$(comm -13 <(echo "$before_dangling" | sort) <(echo "$after_dangling" | sort))
    if [ -n "$new_dangling" ]; then
        docker rmi -f $new_dangling >/dev/null 2>&1
        log "已清理本次构建产生的无标签镜像"
    fi
}

# 显示帮助信息
show_help() {
    echo "端口监控应用管理工具"
    echo "用法: $0 <command>"
    echo ""
    echo "命令列表:"
    echo "  start          启动应用"
    echo "  stop           停止应用"
    echo "  restart        重启应用"
    echo "  build        执行docker构建并打包应用"
    echo "  build-restart 执行docker构建并重启应用"
    echo "  help           显示此帮助信息"
    echo ""
    echo "示例: $0 start"
}

# 主函数
main() {
    check_permissions
    
    if [ $# -eq 0 ]; then
        log "未指定参数，默认执行构建并重启应用"
        build_image
        stop_containers
        start_containers
        return
    fi
    
    case "$1" in
        start)
            start_containers
            ;;
        stop)
            stop_containers
            ;;
        restart)
            stop_containers
            start_containers
            ;;
        build)
            build_image
            ;;
        build-restart)
            build_image
            stop_containers
            start_containers
            ;;
        help | *)
            show_help
            ;;
    esac
}

main "$@"
trap 'echo "脚本中断"; exit 1' INT TERM