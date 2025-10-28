#!/bin/bash

# Feeds安装脚本

install_feeds() {
    local feeds_cache_hit="$1"
    
    source "$LOGGER_SCRIPT"
    source "${GITHUB_WORKSPACE}/scripts/common.sh"
    step_start "INSTALL_FEEDS" "安装Feeds"
    
    cd "$OPENWRT_PATH"
    
    # 更新feeds
    if [ "$feeds_cache_hit" != "true" ]; then
        log "INFO" "更新feeds..."
        show_progress 0 2 "更新feeds"
        if ./scripts/feeds update -a; then
            show_progress 1 2 "更新feeds"
            log "INFO" "Feeds更新成功"
        else
            log "ERROR" "Feeds更新失败"
            exit 1
        fi
    else
        log "INFO" "使用缓存的feeds，跳过更新"
        show_progress 1 2 "使用缓存"
    fi
    
    # 安装feeds
    if [ ! -d "$OPENWRT_PATH/package/feeds" ] || [ -z "$(ls -A $OPENWRT_PATH/package/feeds)" ]; then
        log "INFO" "安装feeds..."
        show_progress 1 2 "安装feeds"
        if ./scripts/feeds install -a; then
            show_progress 2 2 "安装完成"
            log "INFO" "Feeds安装成功"
        else
            log "ERROR" "Feeds安装失败"
            exit 1
        fi
    else
        log "INFO" "feeds已安装，跳过"
        show_progress 2 2 "已安装"
    fi
    
    echo ""
    step_complete "INSTALL_FEEDS" "success"
}

# 导出函数
export -f install_feeds
