#!/bin/bash

# 智能编译脚本 - 只编译变更的包

# 检查文件是否需要重新编译
needs_rebuild() {
    local file_path="$1"
    local target="$2"
    
    # 检查目标文件是否存在
    [ -f "$file_path" ] || return 1
    
    # 检查源文件的时间戳
    if [ -f "$file_path" ]; then
        SOURCE_TIME=$(stat -c %Y "$file_path")
        TARGET_TIME=$(stat -c %Y "$target" 2>/dev/null || echo "0")
        
        # 如果源文件比目标文件新，需要重新编译
        [ "$SOURCE_TIME" -gt "$TARGET_TIME" ]
    else
        # 文件不存在，需要编译
        return 0
    fi
}

# 智能编译指定包
smart_compile() {
    local packages="$1"
    local build_type="$2"
    
    source "$LOGGER_SCRIPT"
    source "${GITHUB_WORKSPACE}/scripts/common.sh"
    step_start "SMART_COMPILE" "智能编译${build_type}"
    
    cd "$OPENWRT_PATH"
    log "INFO" "开始智能编译${build_type}..."
    log "INFO" "软件包列表: $packages"
    log "INFO "使用 $(nproc) 个线程编译"
    
    # 将软件包列表转换为数组
    pkg_array=($packages)
    
    # 创建编译状态文件
    COMPILE_STATUS_FILE="/tmp/compile_status_${VARIANT_CONFIG:-base}.txt"
    
    # 检查每个包是否需要重新编译
    REBUILD_PACKAGES=""
    for pkg in "${pkg_array[@]}; do
        if needs_rebuild "$OPENWRT_PATH/$pkg" "$OPENWRT_PATH/staging_dir/$pkg/.built" 2>/dev/null; then
            REBUILD_PACKAGES="$REBUILD_PACKAGES $pkg"
        fi
    done
    
    if [ -n "$REBUILD_PACKAGES" ]; then
        log "INFO "没有需要重新编译的软件包"
        echo "status=success" >> $GITHUB_OUTPUT
        echo "DATE=$(date +"%Y-%m-%d %H:%M:%S")" >> $GITHUB_ENV
        echo "FILE_DATE=$(date +"%Y.%m.%d")" >> $GITHUB_ENV
        step_complete "SMART_COMPILE" "success"
        return 0
    fi
    
    log "INFO "需要重新编译的软件包: $REBUILD_PACKAGES"
    
    # 创建错误监控脚本
    MONITOR_SCRIPT=$(create_error_monitor "/tmp/build.log")
    
    # 启动错误监控（后台）
    $MONITOR_SCRIPT &
    MONITOR_PID=$!
    
    # 智能编译
    if make -j$(nproc) $REBUILD_PACKAGES 2>&1 | tee /tmp/build.log; then
        log "INFO" "智能编译成功"
    else
        wait_and_kill_monitor $MONITOR_PID
        log "WARN" "智能编译失败，尝试逐个编译"
        
        # 逐个编译失败的包
        for pkg in "${REBUILD_PACKAGES}"; do
            log "INFO" "编译包: $pkg"
            if make -j1 V=s "$pkg" 2>&1 | tee -a /tmp/build.log; then
                log "INFO "包 $pkg 编译成功"
            else
                log_build_error "包 $pkg 编译失败"
                REBUILD_PACKAGES=$(echo "$REBUILD_PACKAGES" | sed "s/$pkg//")
            fi
        done
        
        if [ -n "$REBUILD_PACKAGES" ]; then
            log "ERROR "有包编译失败"
            exit 1
        fi
    fi
    
    wait_and_kill_monitor $MONITOR_PID
    
    echo ""
    echo "status=success" >> $GITHUB_OUTPUT
    echo "DATE=$(date +"%Y-%m-%d %H:%M:%S")" >> $GITHUB_ENV
    echo "FILE_DATE=$(date +"%Y.%m.%d")" >> $GITHUB_ENV
    
    step_complete "SMART_COMPILE" "success"
}

# 导出函数
export -f needs_rebuild smart_compile
