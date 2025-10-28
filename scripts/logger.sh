#!/bin/bash

# 日志系统初始化函数
init_logger() {
    local log_type="$1"  # base, prebuild, variant
    local build_id="$2"  # 构建ID
    
    declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
    CURRENT_LEVEL=${LOG_LEVELS[$BUILD_LOG_LEVEL]}
    LOG_FILE="$GITHUB_WORKSPACE/$BUILD_LOG_FILE"
    REPORT_FILE="$GITHUB_WORKSPACE/$REPORT_FILE"
    
    # 初始化日志文件
    echo "=== ${log_type} Log Started at $(date) ===" > "$LOG_FILE"
    echo "{\"build_id\":\"${build_id}\",\"start_time\":\"$(date -Iseconds)\",\"steps\":[],\"errors\":[],\"warnings\":[]}" > "$REPORT_FILE"
    
    # 导出日志函数
    export_log_functions
}

# 导出日志函数
export_log_functions() {
    cat << 'EOF' > /tmp/log_functions.sh
log() { 
    local level="$1" 
    local message="$2" 
    local step="${3:-$(caller | awk '{print $2}')}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ ${LOG_LEVELS[$level]} -ge $CURRENT_LEVEL ]; then
        case $level in
            DEBUG) echo -e "\033[0;37m[$timestamp] [DEBUG] $message\033[0m" ;;
            INFO)  echo -e "\033[0;34m[$timestamp] [INFO] $message\033[0m" ;;
            WARN)  echo -e "\033[0;33m[$timestamp] [WARN] $message\033[0m" ;;
            ERROR) echo -e "\033[1;41;37m[$timestamp] [ERROR] $message\033[0m" ;;
        esac
        echo "[$timestamp] [$level] [Step: $step] $message" >> "$LOG_FILE"
    fi
}

step_start() { 
    local step_name="$1" 
    local description="$2"
    log "INFO" "▶ 开始执行: $description" "$step_name"
}

step_complete() { 
    local step_name="$1" 
    local status="$2"
    if [ "$status" = "success" ]; then
        log "INFO" "✅ 步骤完成: $step_name" "$step_name"
    elif [ "$status" = "failed" ]; then
        log "ERROR" "❌ 步骤失败: $step_name" "$step_name"
    fi
}
EOF
    
    chmod +x /tmp/log_functions.sh
    source /tmp/log_functions.sh
    export -f log step_start step_complete
}

# 调用初始化函数
init_logger "$1" "$2"
