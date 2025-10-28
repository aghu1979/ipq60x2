#!/bin/bash

# 日志系统初始化脚本

init_logger() {
    local build_id="$1"
    
    # 创建企业级日志框架
    cat > /tmp/logger.sh << 'EOF'
#!/bin/bash

# 日志级别定义
declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
CURRENT_LEVEL=${LOG_LEVELS[$LOG_LEVEL]}

# 日志文件 - 修复路径问题
LOG_FILE="$GITHUB_WORKSPACE/$LOG_FILE"
REPORT_FILE="$GITHUB_WORKSPACE/$REPORT_FILE"

# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$REPORT_FILE")"

# 初始化日志文件
echo "=== Build Log Started at $(date) ===" > "$LOG_FILE"
echo '{"build_id":"'$BUILD_ID'","start_time":"'$(date -Iseconds)'","steps":[],"errors":[],"warnings":[],"build_errors":[]}' > "$REPORT_FILE"

# 记录的构建错误，避免重复
RECORDED_ERRORS=""

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local step="${3:-$(caller | awk '{print $2}')}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 检查日志级别
    if [ ${LOG_LEVELS[$level]} -ge $CURRENT_LEVEL ]; then
        # 控制台输出（带颜色）
        case $level in
            DEBUG) echo -e "\033[0;37m[$timestamp] [DEBUG] $message\033[0m" ;;
            INFO)  echo -e "\033[0;34m[$timestamp] [INFO] $message\033[0m" ;;
            WARN)  echo -e "\033[0;33m[$timestamp] [WARN] $message\033[0m" ;;
            ERROR) echo -e "\033[1;41;37m[$timestamp] [ERROR] $message\033[0m" ;;
        esac
        
        # 文件输出
        echo "[$timestamp] [$level] [Step: $step] $message" >> "$LOG_FILE"
        
        # 更新报告文件
        if [ "$level" = "ERROR" ]; then
            jq --arg step "$step" --arg message "$message" --arg time "$timestamp" \
                '.errors += [{"step":$step,"message":$message,"time":$time}]' "$REPORT_FILE" > "$REPORT_FILE.tmp" && \
                mv "$REPORT_FILE.tmp" "$REPORT_FILE" 2>/dev/null || true
        elif [ "$level" = "WARN" ]; then
            jq --arg step "$step" --arg message "$message" --arg time "$timestamp" \
                '.warnings += [{"step":$step,"message":$message,"time":$time}]' "$REPORT_FILE" > "$REPORT_FILE.tmp" && \
                mv "$REPORT_FILE.tmp" "$REPORT_FILE" 2>/dev/null || true
        fi
    fi
}

# 构建错误记录函数（避免重复）
log_build_error() {
    local error_msg="$1"
    local package="$2"
    local timestamp=$(date -Iseconds)
    
    # 提取更精确的包名
    if [ "$package" = "feeds" ]; then
        package=$(echo "$error_msg" | grep -o 'package/feeds/[^/]*' | head -1 | cut -d'/' -f4)
        if [ -z "$package" ]; then
            package=$(echo "$error_msg" | grep -o 'package/[^/]*' | head -1 | cut -d'/' -f2)
        fi
        if [ -z "$package" ]; then
            package=$(echo "$error_msg" | grep -o '[a-zA-Z0-9_-]*\.tar\.[a-z0-9]+' | head -1 | sed 's/\.tar\.[a-z0-9]+$//')
        fi
        if [ -z "$package" ]; then
            package="nss-firmware"
        fi
    fi
    
    # 检查是否已经记录过这个错误
    local error_key="${package}:${error_msg}"
    if echo "$RECORDED_ERRORS" | grep -q "$error_key"; then
        return 0  # 已经记录过，跳过
    fi
    
    # 添加到已记录错误列表
    RECORDED_ERRORS="${RECORDED_ERRORS}${error_key}\n"
    
    # 高亮显示构建错误
    echo -e "\n\033[1;41;37m🔥 构建错误 🔥\033[0m"
    echo -e "\033[1;31m错误信息: $error_msg\033[0m"
    echo -e "\033[1;31m相关包: $package\033[0m"
    echo -e "\033[1;41;37m================\033[0m\n"
    
    # 记录到日志
    log "ERROR" "构建失败: $error_msg (包: $package)"
    
    # 更新报告文件
    jq --arg msg "$error_msg" --arg pkg "$package" --arg time "$timestamp" \
        '.build_errors += [{"message":$msg,"package":$pkg,"time":$time}]' "$REPORT_FILE" > "$REPORT_FILE.tmp" && \
        mv "$REPORT_FILE.tmp" "$REPORT_FILE" 2>/dev/null || true
    
    # 发送GitHub通知
    echo "::error ::构建失败: $error_msg (包: $package)"
}

# 步骤开始
step_start() {
    local step_name="$1"
    local description="$2"
    local timestamp=$(date -Iseconds)
    
    log "INFO" "▶ 开始执行: $description" "$step_name"
    
    # 更新报告文件
    jq --arg step "$step_name" --arg desc "$description" --arg time "$timestamp" \
        '.steps += [{"name":$step,"description":$desc,"status":"running","start_time":$time}]' "$REPORT_FILE" > "$REPORT_FILE.tmp" && \
        mv "$REPORT_FILE.tmp" "$REPORT_FILE" 2>/dev/null || true
}

# 步骤完成
step_complete() {
    local step_name="$1"
    local status="$2"  # success, failed, warning
    local timestamp=$(date -Iseconds)
    
    if [ "$status" = "success" ]; then
        log "INFO" "✅ 步骤完成: $step_name" "$step_name"
    elif [ "$status" = "failed" ]; then
        log "ERROR" "❌ 步骤失败: $step_name" "$step_name"
    elif [ "$status" = "warning" ]; then
        log "WARN" "⚠️ 步骤完成（有警告）: $step_name" "$step_name"
    fi
    
    # 更新报告文件
    jq --arg step "$step_name" --arg status "$status" --arg time "$timestamp" \
        '(.steps[] | select(.name == $step) |= . + {"status":$status,"end_time":$time})' "$REPORT_FILE" > "$REPORT_FILE.tmp" && \
        mv "$REPORT_FILE.tmp" "$REPORT_FILE" 2>/dev/null || true
}

# 导出函数
export -f log log_build_error step_start step_complete
EOF
    
    chmod +x /tmp/logger.sh
    echo "LOGGER_SCRIPT=/tmp/logger.sh" >> $GITHUB_ENV
    
    # 初始化日志
    source /tmp/logger.sh
    step_start "INIT" "初始化企业级日志系统"
    log "INFO" "构建ID: $build_id"
    log "INFO" "日志级别: $LOG_LEVEL"
    log "INFO" "工作目录: $GITHUB_WORKSPACE"
    step_complete "INIT" "success"
}

# 导出函数
export -f init_logger
