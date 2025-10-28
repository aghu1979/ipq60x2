#!/bin/bash

# 缓存管理脚本

setup_caches() {
    local source_repo="$1"
    local repo_branch="$2"
    local device_target="$3"
    local device_subtarget="$4"
    local feeds_hash="$5"
    
    source "$LOGGER_SCRIPT"
    step_start "SETUP_CACHES" "设置缓存"
    
    # 生成缓存键
    TOOLCHAIN_KEY="${CACHE_VERSION}-toolchain-${source_repo}-${repo_branch}-${device_target}-${device_subtarget}"
    FEEDS_KEY="${CACHE_VERSION}-feeds-${source_repo}-${repo_branch}-${feeds_hash}"
    DL_KEY="${CACHE_VERSION}-dl-${source_repo}-${repo_branch}"
    
    echo "TOOLCHAIN_KEY=$TOOLCHAIN_KEY" >> $GITHUB_ENV
    echo "FEEDS_KEY=$FEEDS_KEY" >> $GITHUB_ENV
    echo "DL_KEY=$DL_KEY" >> $GITHUB_ENV
    
    log "INFO" "缓存键生成完成"
    log "INFO" "工具链缓存键: $TOOLCHAIN_KEY"
    log "INFO" "Feeds缓存键: $FEEDS_KEY"
    log "INFO" "DL缓存键: $DL_KEY"
    
    step_complete "SETUP_CACHES" "success"
}

check_cache_status() {
    local toolchain_hit="$1"
    local feeds_hit="$2"
    local dl_hit="$3"
    
    source "$LOGGER_SCRIPT"
    step_start "CACHE_STATUS" "检查缓存状态"
    
    # 工具链缓存
    if [ "$toolchain_hit" == "true" ]; then
        log "INFO" "✅ 工具链缓存命中"
        CACHE_STATUS_TOOLCHAIN="HIT"
    else
        log "INFO" "❌ 工具链缓存未命中，将重新构建"
        CACHE_STATUS_TOOLCHAIN="MISS"
    fi
    
    # Feeds缓存
    if [ "$feeds_hit" == "true" ]; then
        log "INFO" "✅ Feeds缓存命中"
        CACHE_STATUS_FEEDS="HIT"
    else
        log "INFO" "❌ Feeds缓存未命中，将重新更新"
        CACHE_STATUS_FEEDS="MISS"
    fi
    
    # DL缓存
    if [ "$dl_hit" == "true" ]; then
        log "INFO" "✅ DL软件包缓存命中"
        CACHE_STATUS_DL="HIT"
    else
        log "INFO" "❌ DL软件包缓存未命中，将重新下载"
        CACHE_STATUS_DL="MISS"
    fi
    
    # 显示缓存大小
    for dir in ".ccache" "staging_dir" "feeds" "dl"; do
        if [ -d "$OPENWRT_PATH/$dir" ]; then
            size=$(du -sh "$OPENWRT_PATH/$dir" | cut -f1)
            log "INFO" "$dir 大小: $size"
        fi
    done
    
    # 更新报告
    echo "CACHE_STATUS_TOOLCHAIN=$CACHE_STATUS_TOOLCHAIN" >> $GITHUB_ENV
    echo "CACHE_STATUS_FEEDS=$CACHE_STATUS_FEEDS" >> $GITHUB_ENV
    echo "CACHE_STATUS_DL=$CACHE_STATUS_DL" >> $GITHUB_ENV
    
    step_complete "CACHE_STATUS" "success"
}

refresh_cache() {
    source "$LOGGER_SCRIPT"
    step_start "REFRESH_CACHE" "刷新缓存时间戳"
    
    if [ -d "$OPENWRT_PATH/staging_dir" ]; then
        log "INFO" "刷新staging_dir时间戳..."
        find "$OPENWRT_PATH/staging_dir" -type d -name "stamp" -not -path "*target*" | while read -r dir; do
            find "$dir" -type f -exec touch {} +
        done
        log "INFO" "缓存刷新完成"
    else
        log "WARN" "未找到staging_dir，跳过缓存刷新"
    fi
    
    step_complete "REFRESH_CACHE" "success"
}

# 导出函数
export -f setup_caches check_cache_status refresh_cache
