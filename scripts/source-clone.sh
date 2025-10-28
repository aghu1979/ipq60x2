#!/bin/bash

# 源代码克隆脚本

clone_source() {
    local repo_url="$1"
    local repo_branch="$2"
    
    source "$LOGGER_SCRIPT"
    step_start "CLONE_SOURCE" "克隆源代码"
    
    log "INFO" "检查磁盘空间..."
    df -hT "$GITHUB_WORKSPACE"
    
    log "INFO" "创建工作目录: $OPENWRT_PATH"
    if ! sudo mkdir -p "$OPENWRT_PATH"; then
        log "ERROR" "创建工作目录失败"
        exit 1
    fi
    
    if ! sudo chown -R $(id -u):$(id -g) "$OPENWRT_PATH"; then
        log "ERROR" "设置工作目录权限失败"
        exit 1
    fi
    
    log "INFO" "开始克隆源代码..."
    if git clone --depth 1 -b "$repo_branch" --single-branch "$repo_url" "$OPENWRT_PATH"; then
        log "INFO" "源代码克隆成功"
    else
        log "ERROR" "源代码克隆失败"
        exit 1
    fi
    
    cd "$OPENWRT_PATH"
    
    # 获取版本信息
    VERSION_INFO=$(git show -s --date=short --format="作者: %an<br/>时间: %cd<br/>内容: %s<br/>hash: %H")
    echo "VERSION_INFO=$VERSION_INFO" >> $GITHUB_ENV
    
    VERSION_KERNEL=$(grep -oP 'LINUX_KERNEL_HASH-\K[0-9]+\.[0-9]+\.[0-9]+' target/linux/generic/kernel-6.12 2>/dev/null || echo "未知")
    echo "VERSION_KERNEL=$VERSION_KERNEL" >> $GITHUB_ENV
    
    SOURCE_HASH=$(git rev-parse HEAD)
    echo "SOURCE_HASH=$SOURCE_HASH" >> $GITHUB_ENV
    
    log "INFO" "源码哈希: $SOURCE_HASH"
    log "INFO" "内核版本: $VERSION_KERNEL"
    
    step_complete "CLONE_SOURCE" "success"
}

# 导出函数
export -f clone_source
