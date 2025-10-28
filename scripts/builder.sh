#!/bin/bash

# 编译功能脚本

download_packages() {
    source "$LOGGER_SCRIPT"
    source "${GITHUB_WORKSPACE}/scripts/common.sh"
    step_start "DOWNLOAD_PKGS" "下载软件包"
    
    cd "$OPENWRT_PATH"
    log "INFO" "开始下载软件包..."
    
    # 创建错误监控脚本
    MONITOR_SCRIPT=$(create_error_monitor "/tmp/download.log")
    
    # 启动错误监控（后台）
    $MONITOR_SCRIPT &
    MONITOR_PID=$!
    
    # 监控下载进度
    if make download -j$(nproc) 2>&1 | tee /tmp/download.log; then
        log "INFO" "软件包下载成功"
    else
        wait_and_kill_monitor $MONITOR_PID
        log "ERROR" "软件包下载失败"
        
        # 分析下载错误
        DOWNLOAD_ERRORS=$(grep -E "(failed|Error|ERROR|404|timeout)" /tmp/download.log | tail -5)
        if [ -n "$DOWNLOAD_ERRORS" ]; then
            log_build_error "下载失败: $DOWNLOAD_ERRORS" "下载错误"
        fi
        exit 1
    fi
    
    wait_and_kill_monitor $MONITOR_PID
    step_complete "DOWNLOAD_PKGS" "success"
}

clean_environment() {
    source "$LOGGER_SCRIPT"
    step_start "CLEAN_ENV" "清理构建环境"
    
    cd "$OPENWRT_PATH"
    
    # 检查磁盘空间，如果充足则跳过清理
    AVAILABLE_SPACE=$(df $GITHUB_WORKSPACE | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -gt 10485760 ]; then  # 10GB
      log "INFO" "磁盘空间充足（$(($AVAILABLE_SPACE/1024/1024))GB），跳过清理"
    else
      log "INFO" "磁盘空间不足，执行清理..."
      if make clean; then
          log "INFO" "构建环境清理成功"
      else
          log "WARN" "构建环境清理失败，继续执行"
      fi
    fi
    
    # 确保工具链正确构建
    log "INFO" "准备工具链..."
    if make toolchain/install -j$(nproc); then
        log "INFO" "工具链准备成功"
    else
        log "ERROR" "工具链准备失败"
        exit 1
    fi
    
    step_complete "CLEAN_ENV" "success"
}

compile_firmware() {
    local build_type="$1"
    
    source "$LOGGER_SCRIPT"
    source "${GITHUB_WORKSPACE}/scripts/common.sh"
    step_start "COMPILE" "编译${build_type}"
    
    cd "$OPENWRT_PATH"
    log "INFO" "开始编译${build_type}..."
    log "INFO" "使用 $(nproc) 个线程编译"
    
    # 创建错误监控脚本
    MONITOR_SCRIPT=$(create_error_monitor "/tmp/build.log")
    
    # 定义编译阶段
    stages=("工具链和内核" "系统包" "所有包")
    commands=("toolchain/kernel-headers compile" "package/system/opkg/host/compile" "")
    total=3
    
    for i in "${!stages[@]}"; do
        current=$((i + 1))
        show_progress $current $total "编译${stages[$i]}"
        
        if [ -n "${commands[$i]}" ]; then
            log "INFO" "编译${stages[$i]}..."
            
            # 启动错误监控（后台）
            $MONITOR_SCRIPT &
            MONITOR_PID=$!
            
            if make -j$(nproc) ${commands[$i]} 2>&1 | tee /tmp/build.log; then
                log "INFO" "${stages[$i]}编译成功"
            else
                wait_and_kill_monitor $MONITOR_PID
                log "WARN" "${stages[$i]}并行编译失败，尝试单线程编译"
                
                # 单线程编译时也监控错误
                $MONITOR_SCRIPT &
                MONITOR_PID=$!
                
                if make -j1 V=s ${commands[$i]} 2>&1 | tee /tmp/build.log; then
                    log "INFO" "${stages[$i]}单线程编译成功"
                else
                    wait_and_kill_monitor $MONITOR_PID
                    log "ERROR" "${stages[$i]}编译彻底失败"
                    
                    # 分析最后几行日志，提取关键错误
                    LAST_ERRORS=$(tail -20 /tmp/build.log | grep -E "(failed|Error|ERROR|undefined|multiple)" | tail -3)
                    if [ -n "$LAST_ERRORS" ]; then
                        echo "$LAST_ERRORS" | while read error_line; do
                            log_build_error "$error_line" "编译失败"
                        done
                    fi
                    exit 1
                fi
            fi
            
            wait_and_kill_monitor $MONITOR_PID
        else
            log "INFO" "编译所有包..."
            
            # 启动错误监控（后台）
            $MONITOR_SCRIPT &
            MONITOR_PID=$!
            
            if make -j$(nproc) 2>&1 | tee /tmp/build.log; then
                log "INFO" "所有包编译成功"
            else
                wait_and_kill_monitor $MONITOR_PID
                log "WARN" "并行编译失败，尝试单线程编译"
                
                # 单线程编译时也监控错误
                $MONITOR_SCRIPT &
                MONITOR_PID=$!
                
                if make -j1 V=s 2>&1 | tee /tmp/build.log; then
                    log "INFO" "单线程编译成功"
                else
                    wait_and_kill_monitor $MONITOR_PID
                    log "ERROR" "编译彻底失败"
                    
                    # 分析最后几行日志，提取关键错误
                    LAST_ERRORS=$(tail -20 /tmp/build.log | grep -E "(failed|Error|ERROR|undefined|multiple)" | tail -3)
                    if [ -n "$LAST_ERRORS" ]; then
                        echo "$LAST_ERRORS" | while read error_line; do
                            log_build_error "$error_line" "编译失败"
                        done
                    fi
                    exit 1
                fi
            fi
            
            wait_and_kill_monitor $MONITOR_PID
        fi
    done
    
    echo ""
    echo "status=success" >> $GITHUB_OUTPUT
    echo "DATE=$(date +"%Y-%m-%d %H:%M:%S")" >> $GITHUB_ENV
    echo "FILE_DATE=$(date +"%Y.%m.%d")" >> $GITHUB_ENV
    
    step_complete "COMPILE" "success"
}

# 导出函数
export -f download_packages clean_environment compile_firmware
