#!/bin/bash

# 初始化日志系统
init_logger() {
    local build_id="$1"
    
    # 设置日志文件路径
    LOG_FILE="$GITHUB_WORKSPACE/$BUILD_LOG_FILE"
    REPORT_FILE="$GITHUB_WORKSPACE/$REPORT_FILE"
    
    # 创建日志文件
    echo "=== Log Started at $(date) ===" > "$LOG_FILE"
    echo '{"build_id":"'$build_id'","start_time":"'$(date -Iseconds)'","steps":[],"errors":[],"warnings":[]}' > "$REPORT_FILE"
    
    # 导出环境变量
    export LOG_FILE REPORT_FILE
}

# 简单的日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$timestamp] [$level] $message"
}

step_start() {
    local step_name="$1"
    local description="$2"
    echo "▶ 开始执行: $description"
    log "INFO" "Step $step_name started: $description"
}

step_complete() {
    local step_name="$1"
    local status="$2"
    if [ "$status" = "success" ]; then
        echo "✅ 步骤完成: $step_name"
        log "INFO" "Step $step_name completed successfully"
    elif [ "$status" = "failed" ]; then
        echo "❌ 步骤失败: $step_name"
        log "ERROR" "Step $step_name failed"
    fi
}

# 如果脚本被直接调用，执行初始化
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    init_logger "$1"
fi
