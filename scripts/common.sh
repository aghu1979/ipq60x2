#!/bin/bash

# 通用函数库

# 查找配置文件函数
find_config_file() {
    local base_name="$1"
    local config_dir="${GITHUB_WORKSPACE}/${CONFIG_BASE_DIR}"
    
    # 尝试不同格式
    for ext in ".config" ".config.txt"; do
        if [ -f "${config_dir}/${base_name}${ext}" ]; then
            echo "${config_dir}/${base_name}${ext}"
            return 0
        fi
    done
    
    # 使用find查找
    local found_file=$(find "$config_dir" -iname "${base_name}.config*" -type f | head -n 1)
    if [ -n "$found_file" ]; then
        echo "$found_file"
        return 0
    fi
    
    return 1
}

# 检查命令执行结果
check_result() {
    local result=$1
    local message="$2"
    local step="$3"
    
    if [ $result -eq 0 ]; then
        log "INFO" "✅ $message" "$step"
        return 0
    else
        log "ERROR" "❌ $message" "$step"
        return 1
    fi
}

# 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r\033[0;36m[%3d%%] [" "$percent"
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %s\033[0m" "$description"
}

# 创建错误监控脚本
create_error_monitor() {
    local log_file="$1"
    local monitor_script="/tmp/monitor_errors.sh"
    
    cat > "$monitor_script" << EOF
#!/bin/bash
LOG_FILE="$log_file"
# 扩展错误模式，包含更多错误类型
ERROR_PATTERNS=(
    "failed to build"
    "failed to install"
    "Error:"
    "ERROR:"
    "error:"
    "make.*\*\*\*.*Error"
    "command terminated with signal"
    "cannot stat"
    "No such file or directory"
    "Permission denied"
    "Segmentation fault"
    "Compilation failed"
    "Build failed"
    "undefined reference"
    "multiple definition"
)

# 记录的错误，避免重复
RECORDED_ERRORS=""

# 简化的错误记录函数，避免递归调用
simple_log_error() {
    local error_msg="\$1"
    local package="\$2"
    
    echo -e "\n\033[1;41;37m🔥 构建错误 🔥\033[0m"
    echo -e "\033[1;31m错误信息: \$error_msg\033[0m"
    echo -e "\033[1;31m相关包: \$package\033[0m"
    echo -e "\033[1;41;37m================\033[0m\n"
}

tail -f "\$LOG_FILE" | while read line; do
    for pattern in "\${ERROR_PATTERNS[@]}"; do
        if echo "\$line" | grep -q "\$pattern"; then
            # 提取包名 - 改进包名提取逻辑
            PACKAGE=\$(echo "\$line" | grep -oE 'package/[^/]*|/tmp/[^/]*' | head -1 | cut -d'/' -f2)
            if [ -z "\$PACKAGE" ]; then
                PACKAGE=\$(echo "\$line" | grep -oE '[a-zA-Z0-9_-]+\.tar\.[a-z0-9]+' | head -1 | sed 's/\.tar\.[a-z0-9]+$//')
            fi
            if [ -z "\$PACKAGE" ]; then
                PACKAGE=\$(echo "\$line" | grep -oE 'ERROR: package/[^\s]+' | sed 's/ERROR: package\///')
            fi
            if [ -z "\$PACKAGE" ]; then
                PACKAGE="未知"
            fi
            
            # 检查是否已经记录过这个错误
            ERROR_KEY="\${PACKAGE}:\${line}"
            if echo "\$RECORDED_ERRORS" | grep -q "\$ERROR_KEY"; then
                continue  # 已经记录过，跳过
            fi
            
            # 添加到已记录错误列表
            RECORDED_ERRORS="\${RECORDED_ERRORS}\${ERROR_KEY}\n"
            
            # 调用简化的错误记录函数
            simple_log_error "\$line" "\$PACKAGE"
            break  # 只记录第一个匹配的错误模式
        fi
    done
done
EOF
    
    chmod +x "$monitor_script"
    echo "$monitor_script"
}

# 等待并终止监控进程
wait_and_kill_monitor() {
    local monitor_pid="$1"
    
    if [ -n "$monitor_pid" ] && kill -0 "$monitor_pid" 2>/dev/null; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
}

# 执行自定义脚本
execute_custom_script() {
    local script_path="$1"
    local script_name="$2"
    
    # 确保日志系统已加载
    if [ -z "$(type -t log)" ]; then
        # 如果日志系统未加载，使用简单的日志函数
        log() {
            local level="$1"
            local message="$2"
            echo "[$level] $message"
        }
    fi
    
    if [ -f "$script_path" ]; then
        log "INFO" "执行${script_name}脚本: $script_path"
        chmod +x "$script_path" || {
            log "ERROR" "设置${script_name}脚本权限失败"
            return 1
        }
        
        cd "$OPENWRT_PATH"
        if "$script_path"; then
            log "INFO" "${script_name}脚本执行成功"
            return 0
        else
            log "ERROR" "${script_name}脚本执行失败"
            return 1
        fi
    else
        log "WARN" "${script_name}脚本不存在，跳过"
        return 0
    fi
}

# 导出函数
export -f find_config_file check_result show_progress create_error_monitor wait_and_kill_monitor execute_custom_script
