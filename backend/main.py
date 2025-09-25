from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import subprocess
import re
import socket
import os
import sys
from pydantic import BaseModel
from typing import List, Dict, Optional, Union

# 检查是否在Docker容器中运行（通过环境变量）
def is_running_in_docker() -> bool:
    # 检查环境变量
    if os.environ.get("IN_DOCKER") == "true":
        return True
    
    # 作为后备，继续检查是否存在/host/proc目录
    return os.path.exists("/host/proc")

# 初始化应用
app = FastAPI(title="端口监控API")

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 确定前端静态文件目录的绝对路径
def get_frontend_directory() -> str:
    """根据运行环境简单确定前端静态文件目录的位置"""
    # 根据是否在Docker容器中运行返回不同路径
    if is_running_in_docker():
        # 在Docker容器中运行时，前端文件位于/app/frontend
        # 这由Dockerfile的COPY命令保证
        return "/app/frontend"
    else:
        # 在宿主机上运行时，前端文件位于项目根目录下的frontend
        # 获取当前文件(main.py)的绝对路径
        current_file_path = os.path.abspath(__file__)
        # 获取当前文件所在目录(backend目录)
        backend_dir = os.path.dirname(current_file_path)
        # 返回backend的父目录下的frontend
        return os.path.join(os.path.dirname(backend_dir), "frontend")

# 挂载静态文件目录
frontend_dir = get_frontend_directory()
app.mount("/static", StaticFiles(directory=frontend_dir), name="static")

class PortInfo(BaseModel):
    port: str
    protocol: str
    status: str
    local_address: str
    remote_address: str
    pid: Optional[str] = None
    process: Optional[str] = None
    user: Optional[str] = None

def get_port_owner(pid: str) -> Optional[str]:
    """获取端口所属用户（兼容容器内和宿主机直接运行）"""
    try:
        # 使用is_running_in_docker函数判断是否在Docker容器中运行
        if is_running_in_docker():
            # 在Docker容器中运行，使用nsenter命令进入宿主机的命名空间执行ps命令
            command = ["nsenter", "--net=/host/proc/1/ns/net", "--mount=/host/proc/1/ns/mnt", "ps", "-o", "user=", "-p", pid]
        else:
            # 在宿主机直接运行，直接使用ps命令
            command = ["ps", "-o", "user=", "-p", pid]
        
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True
        )
        
        user = result.stdout.strip()
        return user
    except Exception:
        return None

def parse_ss_output(output: str) -> List[Dict]:
    """解析ss命令的输出"""
    ports = []
    # 用于去重的集合，使用(端口,协议,进程)作为唯一标识
    seen_ports = set()
    
    # 正则表达式匹配ss输出行 - 修改以匹配实际输出格式
    # 匹配带进程信息的行，考虑不同空格模式和引号格式
    pattern = re.compile(
        r'(tcp|udp)\s+(\w+)\s+\d+\s+\d+\s+([\d.:%\[\]]+)\s+([\d.:%\[\]]+\*?)\s+users:\(\(\"(.*)\",pid=(\d+).*\)'
    )
    
    # 不包含进程信息的行，考虑不同空格模式
    pattern_no_pid = re.compile(
        r'(tcp|udp)\s+(\w+)\s+\d+\s+\d+\s+([\d.:%\[\]]+)\s+([\d.:%\[\]]+\*?)'
    )
    
    newline = '\n'
    
    # 提取所有包含users:的行进行特殊分析
    all_lines = output.split(newline)
    
    for line in all_lines:
        line = line.strip()
        if not line:
            continue
            
        # 跳过标题行
        if line.startswith('Netid'):
            continue
            
        match = pattern.match(line)
        if match:
            protocol = match.group(1).upper()
            status = match.group(2).upper()
            local_addr = match.group(3)
            remote_addr = match.group(4)
            process = match.group(5)
            pid = match.group(6)
            
            # 处理IPv6地址格式
            if '[' in local_addr:
                # IPv6地址格式: [::]:80
                port_match = re.search(r':(\d+)$', local_addr)
                if port_match:
                    port = port_match.group(1)
                else:
                    port = '0'
            else:
                # 提取端口号
                port = local_addr.split(':')[-1]
            
            # 获取进程所有者
            user = get_port_owner(pid)
            
            port_info = {
                'port': port,
                'protocol': protocol,
                'status': status,
                'local_address': local_addr,
                'remote_address': remote_addr,
                'pid': pid,
                'process': process,
                'user': user
            }
            
            # 创建唯一标识符用于去重
            port_key = (port, protocol, pid)
            if port_key not in seen_ports:
                seen_ports.add(port_key)
                ports.append(port_info)
        else:
            # 尝试匹配没有进程信息的行
            match_no_pid = pattern_no_pid.match(line)
            if match_no_pid:
                protocol = match_no_pid.group(1).upper()
                status = match_no_pid.group(2).upper()
                local_addr = match_no_pid.group(3)
                remote_addr = match_no_pid.group(4)
                
                # 处理IPv6地址格式
                if '[' in local_addr:
                    port_match = re.search(r':(\d+)$', local_addr)
                    if port_match:
                        port = port_match.group(1)
                    else:
                        port = '0'
                else:
                    # 提取端口号
                    port = local_addr.split(':')[-1]
                    
                    port_info = {
                        'port': port,
                        'protocol': protocol,
                        'status': status,
                        'local_address': local_addr,
                        'remote_address': remote_addr,
                        'pid': None,
                        'process': None,
                        'user': None
                    }
                    
                    # 创建唯一标识符用于去重 - 无进程信息时使用(端口,协议,None)
                    port_key = (port, protocol, None)
                    if port_key not in seen_ports:
                        seen_ports.add(port_key)
                        ports.append(port_info)
    
    return ports

@app.get("/api/ports", tags=["端口信息"])
async def get_ports(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(15, ge=1, le=100, description="每页数量"),
    sort_field: str = Query("port", description="排序字段"),
    sort_direction: str = Query("asc", regex="^(asc|desc)$", description="排序方向"),
    search: str = Query(None, description="搜索关键词（端口号）")
):
    """获取宿主机的所有端口信息（兼容容器内和宿主机直接运行），支持分页、排序和搜索"""
    try:
        # 使用is_running_in_docker函数判断是否在Docker容器中运行
        if is_running_in_docker():
            # 在Docker容器中运行，使用nsenter命令进入宿主机的网络和挂载命名空间
            # 这样才能获取完整的进程信息（包括PID、进程名等）
            result = subprocess.run(
                ["nsenter", "--net=/host/proc/1/ns/net", "--mount=/host/proc/1/ns/mnt", "ss", "-tulpn"],
                capture_output=True,
                text=True
            )
        else:
            # 在宿主机直接运行，直接使用ss命令
            result = subprocess.run(
                ["ss", "-tulpn"],
                capture_output=True,
                text=True
            )
        
        # 解析输出
        ports_info = parse_ss_output(result.stdout)
        
        # 搜索过滤
        if search:
            ports_info = [port for port in ports_info if search in port["port"]]
        
        # 排序
        valid_sort_fields = {"port", "protocol", "status", "local_address", "remote_address", "pid", "process", "user"}
        if sort_field in valid_sort_fields:
            if sort_field == "port":
                # 端口号按数字排序
                ports_info.sort(key=lambda x: int(x["port"]) if x["port"].isdigit() else 0,
                               reverse=(sort_direction == "desc"))
            else:
                # 其他字段按字符串排序
                ports_info.sort(key=lambda x: str(x.get(sort_field, "")) if x.get(sort_field) is not None else "",
                               reverse=(sort_direction == "desc"))
        
        # 分页
        total_count = len(ports_info)
        start_index = (page - 1) * page_size
        end_index = start_index + page_size
        paginated_ports = ports_info[start_index:end_index]
        
        # 返回分页结果，包含数据和元信息
        return {
            "data": paginated_ports,
            "total": total_count,
            "page": page,
            "page_size": page_size,
            "total_pages": (total_count + page_size - 1) // page_size
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取端口信息失败: {str(e)}")



@app.get("/{full_path:path}", include_in_schema=False)
async def serve_frontend(full_path: str):
    """提供前端静态文件"""
    # 使用动态确定的前端目录
    file_path = os.path.join(frontend_dir, full_path)
    
    # 如果路径是目录，尝试返回index.html
    if os.path.isdir(file_path):
        file_path = os.path.join(file_path, "index.html")
    
    # 检查文件是否存在
    if os.path.exists(file_path) and os.path.isfile(file_path):
        return FileResponse(file_path)
    
    # 如果文件不存在，返回主页面
    return FileResponse(os.path.join(frontend_dir, "index.html"))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=True)
