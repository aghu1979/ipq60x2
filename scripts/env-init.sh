#!/bin/bash

# 环境初始化脚本

init_environment() {
    source "$LOGGER_SCRIPT"
    step_start "ENV_INIT" "初始化构建环境"
    
    # 设置错误处理
    set -euo pipefail
    trap 'log "ERROR" "命令执行失败: $BASH_COMMAND ($LINENO)"' ERR
    
    # 检查是否使用缓存的环境
    # 通过检查环境变量而不是直接使用GitHub Actions变量
    if [ "${USE_CACHE_ENV:-false}" = "true" ]; then
        log "INFO" "使用缓存的环境，跳过初始化"
        step_complete "ENV_INIT" "success"
        return 0
    fi
    
    log "INFO" "更新系统包..."
    # 使用更可靠的源
    if sudo -E apt-get -y update; then
        log "INFO" "系统包更新成功"
    else
        log "ERROR" "系统包更新失败"
        exit 1
    fi
    
    log "INFO" "安装基础构建工具..."
    # 安装基础构建工具，排除Java和Python（使用官方actions）
    if sudo -E apt-get -y install --no-install-recommends \
        build-essential \
        ccache \
        ecj \
        fastjar \
        file \
        g++ \
        gawk \
        gettext \
        javacc \
        libelf-dev \
        libncurses5-dev \
        libncursesw5-dev \
        libssl-dev \
        rsync \
        subversion \
        swig \
        unzip \
        wget \
        zip \
        zlib1g-dev \
        curl \
        ca-certificates \
        gnupg \
        software-properties-common \
        apt-transport-https \
        lsb-release \
        git; then
        log "INFO" "基础构建工具安装成功"
    else
        log "ERROR" "基础构建工具安装失败"
        exit 1
    fi
    
    # 清理可能存在的Android SDK和其他不需要的包
    log "INFO" "清理不需要的包..."
    # 清理Android相关
    if [ -d "/usr/local/lib/android" ]; then
        log "INFO" "发现Android SDK，正在清理..."
        sudo rm -rf /usr/local/lib/android 2>/dev/null || true
    fi
    
    # 清理Android相关包
    sudo apt-get -y purge android-sdk-* 2>/dev/null || true
    sudo apt-get -y autoremove --purge 2>/dev/null || true
    
    # 清理不需要的语言环境
    sudo apt-get -y purge \
        openjdk-* \
        default-jre \
        default-jdk \
        python3-* \
        python-* \
        2>/dev/null || true
    
    # 安装GitHub CLI
    log "INFO" "安装GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install gh -y
    
    # 配置时区
    log "INFO" "配置时区..."
    sudo -E systemctl daemon-reload || log "WARN" "重载系统服务失败"
    if sudo timedatectl set-timezone "$TZ"; then
        log "INFO" "时区设置成功: $TZ"
    else
        log "WARN" "时区设置失败"
    fi
    
    # 配置ccache
    log "INFO" "配置ccache..."
    if ! command -v ccache &> /dev/null; then
        log "WARN" "ccache未安装"
    else
        # 设置ccache缓存目录
        export CCACHE_DIR=/tmp/ccache
        mkdir -p $CCACHE_DIR
        log "INFO" "ccache目录设置为: $CCACHE_DIR"
    fi
    
    # 显示系统信息
    log "INFO" "=== 系统信息 ==="
    log "INFO" "CPU核心数: $(nproc)"
    log "INFO" "内存总量: $(free -h | grep '^Mem:' | awk '{print $2}')"
    log "INFO" "磁盘空间: $(df -h $GITHUB_WORKSPACE | tail -1 | awk '{print $4}')"
    log "INFO" "Ubuntu版本: $(lsb_release -d -s 2>/dev/null || echo 'Unknown')"
    
    step_complete "ENV_INIT" "success"
}

# 导出函数
export -f init_environment
