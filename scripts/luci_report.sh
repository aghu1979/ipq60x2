#!/bin/bash
# Luci软件包报告脚本
# 功能：生成和显示Luci软件包报告

# 完全不使用 set -euo pipefail，避免管道错误导致脚本退出
set -e

# 使用说明
usage() {
    echo "用法: $0 <config_file> <output_file> [stage] [before_config]"
    echo "示例: $0 .config luci_report.txt 'defconfig后' .config.before_defconfig"
    echo "      $0 .config luci_report.txt 'defconfig对比' .config.before_defconfig"
    exit 1
}

# 检查参数
if [[ $# -lt 2 ]]; then
    usage
fi

CONFIG_FILE="$1"
OUTPUT_FILE="$2"
STAGE="${3:-'报告'}"
BEFORE_CONFIG="${4:-}"

# 日志函数
log_info() {
    echo -e "\033[32m[INFO]\033[0m $*"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $*"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $*"
}

# 确保输出目录存在
ensure_output_dir() {
    local output_dir=$(dirname "$OUTPUT_FILE")
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" || {
            log_error "无法创建输出目录: $output_dir"
            return 1
        }
    fi
}

# 提取Luci软件包
extract_luci_packages() {
    local config="$1"
    local output="$2"
    
    # 检查配置文件是否存在
    if [[ ! -f "$config" ]]; then
        log_warn "配置文件不存在: $config"
        touch "$output"
        return 0
    fi
    
    log_info "提取Luci软件包..."
    
    # 使用更稳健的方式提取Luci包
    if grep -q "^CONFIG_PACKAGE_luci.*=y$" "$config" 2>/dev/null; then
        # 先检查是否有匹配的行
        local pkg_count=$(grep -c "^CONFIG_PACKAGE_luci.*=y$" "$config" 2>/dev/null || echo "0")
        if [[ $pkg_count -gt 0 ]]; then
            # 提取并处理
            grep "^CONFIG_PACKAGE_luci.*=y$" "$config" 2>/dev/null | \
                sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | \
                sort > "$output_file" 2>/dev/null || {
                log_warn "提取Luci软件包失败，使用备用方法"
                # 备用方法
                grep "^CONFIG_PACKAGE_luci.*=y$" "$config" 2>/dev/null | \
                    awk -F= '{print $1}' | \
                    sed 's/^CONFIG_PACKAGE_//' | \
                    sed 's/=y$//' | \
                    sort > "$output_file" 2>/dev/null || {
                        log_error "备用方法也失败"
                        touch "$output_file"
                    }
            }
            
            # 验证输出文件
            if [[ -f "$output_file" ]]; then
                local count=$(cat "$output_file" 2>/dev/null | wc -l || echo "0")
                log_info "提取到 $count 个Luci软件包"
            else
                log_warn "输出文件创建失败"
            fi
        else
            log_warn "未找到Luci软件包配置"
            touch "$output_file"
        fi
    else
        log_warn "未找到Luci软件包配置"
        touch "$output"
    fi
}

# 分类Luci软件包
categorize_packages() {
    local input_file="$1"
    local output_file="$2"
    
    # 检查输入文件是否存在
    if [[ ! -f "$input_file" ]] || [[ ! -s "$input_file" ]]; then
        log_warn "输入文件为空或不存在: $input_file"
        cat > "$output_file" << 'EOF'
# Luci软件包分类报告

## 统计信息
- 总包数: 0

## 分类统计
- 核心组件: 0 个
- 网络管理: 0 个
- 系统工具: 0 个
- 主题界面: 0 个
- 协议支持: 0 个
- 其他软件包: 0 个

## 详细列表
无软件包
EOF
        return
    fi
    
    # 定义分类
    local -a categories=(
        "核心组件:luci-base luci-compat luci-lib-"
        "网络管理:luci-app-"
        "系统工具:luci-i18n- luci-mod-"
        "主题界面:luci-theme-"
        "协议支持:luci-proto-"
    )
    
    # 创建报告文件
    {
        echo "# Luci软件包分类报告"
        echo ""
        echo "## 统计信息"
        
        # 统计总数
        local total_count
        total_count=$(cat "$input_file" 2>/dev/null | wc -l || echo "0")
        echo "- 总包数: $total_count"
        echo ""
        echo "## 分类统计"
        
        # 按分类统计
        local categorized_count=0
        for category in "${categories[@]}"; do
            local pattern="${category#*:}"
            local count=0
            
            while IFS= read -r pkg; do
                if [[ "$pkg" == $pattern* ]]; then
                    ((count++))
                    ((categorized_count++))
                fi
            done < "$input_file"
            
            echo "- ${category%:*}: $count 个"
        done
        
        local other_count=$((total_count - categorized_count))
        echo "- 其他软件包: $other_count 个"
        echo ""
        echo "## 详细列表"
        
        # 详细列表
        for category in "${categories[@]}"; do
            local pattern="${category#*:}"
            echo ""
            echo "### ${category%:*}"
            
            local found=false
            while IFS= read -r pkg; do
                if [[ "$pkg" == $pattern* ]]; then
                    echo "  - $pkg"
                    found=true
                fi
            done < "$input_file"
            
            if [[ "$found" == "false" ]]; then
                echo "  无"
            fi
        done
        
        # 其他软件包
        if [[ $other_count -gt 0 ]]; then
            echo ""
            echo "### 其他软件包"
            
            while IFS= read -r pkg; do
                local categorized=false
                for category in "${categories[@]}"; do
                    local pattern="${category#*:}"
                    if [[ "$pkg" == $pattern* ]]; then
                        categorized=true
                        break
                    fi
                done
                
                if [[ "$categorized" == "false" ]]; then
                    echo "  - $pkg"
                fi
            done < "$input_file"
        fi
    } > "$output_file"
}

# 生成对比报告
generate_comparison_report() {
    local before_file="$1"
    local after_file="$2"
    local output_file="$3"
    
    log_info "生成Luci软件包对比报告..."
    
    # 检查文件是否存在
    if [[ ! -f "$before_file" ]]; then
        log_warn "对比前的配置文件不存在: $before_file"
        return
    fi
    
    if [[ ! -f "$after_file" ]]; then
        log_warn "对比后的配置文件不存在: $after_file"
        return
    fi
    
    # 使用纯bash生成对比报告，避免Python问题
    {
        echo "# Luci软件包变化报告 (make defconfig前后对比)"
        echo ""
        echo "## 统计信息"
        
        # 提取包列表
        local before_pkgs=()
        local after_pkgs=()
        
        # 读取defconfig前的包
        while IFS= read -r pkg; do
            if [[ -n "$pkg" ]]; then
                before_pkgs+=("$pkg")
            fi
        done < "$before_file"
        
        # 读取defconfig后的包
        while IFS= read -r pkg; do
            if [[ -n "$pkg" ]]; then
                after_pkgs+=("$pkg")
            fi
        done < "$after_file"
        
        # 计算统计
        local before_count=${#before_pkgs[@]}
        local after_count=${#after_pkgs[@]}
        
        # 计算差异
        local added=()
        local removed=()
        
        # 找出新增的包
        for pkg in "${after_pkgs[@]}"; do
            local found=false
            for b_pkg in "${before_pkgs[@]}"; do
                if [[ "$pkg" == "$b_pkg" ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == "false" ]]; then
                added+=("$pkg")
            fi
        done
        
        # 找出移除的包
        for pkg in "${before_pkgs[@]}"; do
            local found=false
            for a_pkg in "${after_pkgs[@]}"; do
                if [[ "$pkg" == "$a_pkg" ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == "false" ]]; then
                removed+=("$pkg")
            fi
        done
        
        echo "- defconfig前: $before_count 个包"
        echo "- defconfig后: $after_count 个包"
        echo "- 新增: ${#added[@]} 个包"
        echo "- 移除: ${#removed[@]} 个包"
        echo ""
        echo "## 新增的软件包（由依赖自动引入）"
        
        if [[ ${#added[@]} -gt 0 ]]; then
            for pkg in "${added[@]}"; do
                echo "  + $pkg"
            done
        else
            echo "  无"
        fi
        
        echo ""
        echo "## 移除的软件包（因依赖问题被禁用）"
        
        if [[ ${#removed[@]} -gt 0 ]]; then
            for pkg in "${removed[@]}"; do
                echo "  - $pkg"
            done
        else
            echo "  无"
        fi
        
        echo ""
        echo "## 完整的软件包列表（defconfig后）"
        
        for pkg in "${after_pkgs[@]}"; do
            echo "  * $pkg"
        done
    } > "$output_file"
}

# 主函数
main() {
    log_info "生成Luci软件包报告 ($STAGE)..."
    
    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "配置文件不存在: $CONFIG_FILE"
    fi
    
    # 确保输出目录存在
    ensure_output_dir || {
        log_error "无法创建输出目录，但继续执行"
    }
    
    # 创建临时文件
    local temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT
    
    # 提取Luci包
    extract_luci_packages "$CONFIG_FILE" "$temp_file"
    
    # 如果是对比模式，生成对比报告
    if [[ "$STAGE" == "defconfig对比" ]] && [[ -n "$BEFORE_CONFIG" ]]; then
        local before_temp=$(mktemp)
        trap "rm -f $before_temp" EXIT
        extract_luci_packages "$BEFORE_CONFIG" "$before_temp"
        
        # 生成对比报告
        generate_comparison_report "$before_temp" "$temp_file" "$OUTPUT_FILE"
        
        # 显示报告
        if [[ -f "$OUTPUT_FILE" ]]; then
            echo ""
            echo -e "\033[1;34m========== make defconfig前后对比报告 ==========\033[0m"
            echo ""
            cat "$OUTPUT_FILE"
            echo ""
        fi
    else
        # 生成分类报告
        categorize_packages "$temp_file" "$OUTPUT_FILE"
        
        # 显示报告内容
        if [[ -f "$OUTPUT_FILE" ]]; then
            echo ""
            echo -e "\033[1;34m========== $STAGE 的Luci软件包报告 ==========\033[0m"
            echo ""
            cat "$OUTPUT_FILE"
            echo ""
        fi
    fi
    
    log_info "Luci软件包报告已生成: $OUTPUT_FILE"
}

# 执行主函数
main "$@"
