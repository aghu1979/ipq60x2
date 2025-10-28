#!/bin/bash

# 环境初始化脚本

init_environment() {
    source "$LOGGER_SCRIPT"
    step_start "ENV_INIT" "初始化构建环境"
    
    # 设置错误处理
    set -euo pipefail
    trap 'log "ERROR" "命令执行失败: $BASH_COMMAND ($LINENO)"' ERR
    
    log "INFO" "更新系统包..."
    if sudo -E apt-get -y update; then
        log "INFO" "系统包更新成功"
    else
        log "ERROR" "系统包更新失败"
        exit 1
    fi
    
    log "INFO" "安装依赖..."
    if sudo -E apt-get -y install $(curl -fsSL is.gd/depends_ubuntu_2204); then
        log "INFO" "依赖安装成功"
    else
        log "ERROR" "依赖安装失败"
        exit 1
    fi
    
    # 安装GitHub CLI
    log "INFO" "安装GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install gh -y
    
    log "INFO" "配置时区..."
    sudo -E systemctl daemon-reload || log "WARN" "重载系统服务失败"
    if sudo timedatectl set-timezone "$TZ"; then
        log "INFO" "时区设置成功: $TZ"
    else
        log "WARN" "时区设置失败"
    fi
    
    # 显示系统信息
    log "INFO" "=== 系统信息 ==="
    log "INFO" "CPU核心数: $(nproc)"
    log "INFO" "内存总量: $(free -h | grep '^Mem:' | awk '{print $2}')"
    log "INFO" "磁盘空间: $(df -h $GITHUB_WORKSPACE | tail -1 | awk '{print $4}')"
    
    step_complete "ENV_INIT" "success"
}

# 导出函数
export -f init_environment
