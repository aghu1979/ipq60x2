#!/bin/bash
# Luci软件包报告脚本
# 功能：生成和显示Luci软件包报告

set -euo pipefail

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 使用说明
usage() {
    echo "用法: $0 <config_file> <output_file> [stage]"
    echo "示例: $0 .config luci_report.txt 'defconfig后'"
    exit 1
}

# 检查参数
if [[ $# -lt 2 ]]; then
    usage
fi

CONFIG_FILE="$1"
OUTPUT_FILE="$2"
STAGE="${3:-'报告'}"

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
        mkdir -p "$output_dir" || error_exit "无法创建输出目录: $output_dir"
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
    
    # 提取所有Luci包
    if grep -q "^CONFIG_PACKAGE_luci.*=y$" "$config"; then
        grep "^CONFIG_PACKAGE_luci.*=y$" "$config" | \
            sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | \
            sort > "$output"
        
        local count=$(wc -l < "$output")
        log_info "提取到 $count 个Luci软件包"
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
    declare -A categories=(
        ["核心组件"]="luci-base luci-compat luci-lib-"
        ["网络管理"]="luci-app-"
        ["系统工具"]="luci-i18n- luci-mod-"
        ["主题界面"]="luci-theme-"
        ["协议支持"]="luci-proto-"
    )
    
    cat > "$output_file" << 'EOF'
# Luci软件包分类报告

## 统计信息
EOF
    
    # 统计总数
    local total_count=$(wc -l < "$input_file")
    echo "- 总包数: $total_count" >> "$output_file"
    echo "" >> "$output_file"
    echo "## 分类统计" >> "$output_file"
    
    # 按分类统计
    local categorized_count=0
    for category in "${!categories[@]}"; do
        local pattern="${categories[$category]}"
        local count=0
        
        while IFS= read -r pkg; do
            if [[ "$pkg" == $pattern* ]]; then
                ((count++))
                ((categorized_count++))
            fi
        done < "$input_file"
        
        echo "- $category: $count 个" >> "$output_file"
    done
    
    local other_count=$((total_count - categorized_count))
    echo "- 其他软件包: $other_count 个" >> "$output_file"
    echo "" >> "$output_file"
    
    # 详细列表
    echo "## 详细列表" >> "$output_file"
    
    for category in "${!categories[@]}"; do
        local pattern="${categories[$category]}"
        echo "" >> "$output_file"
        echo "### $category" >> "$output_file"
        
        local found=false
        while IFS= read -r pkg; do
            if [[ "$pkg" == $pattern* ]]; then
                echo "  - $pkg" >> "$output_file"
                found=true
            fi
        done < "$input_file"
        
        if [[ "$found" == "false" ]]; then
            echo "  无" >> "$output_file"
        fi
    done
    
    # 其他软件包
    if [[ $other_count -gt 0 ]]; then
        echo "" >> "$output_file"
        echo "### 其他软件包" >> "$output_file"
        
        while IFS= read -r pkg; do
            local categorized=false
            for pattern in "${categories[@]}"; do
                if [[ "$pkg" == $pattern* ]]; then
                    categorized=true
                    break
                fi
            done
            
            if [[ "$categorized" == "false" ]]; then
                echo "  - $pkg" >> "$output_file"
            fi
        done < "$input_file"
    fi
}

# 主函数
main() {
    log_info "生成Luci软件包报告 ($STAGE)..."
    
    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "配置文件不存在: $CONFIG_FILE"
    fi
    
    # 确保输出目录存在
    ensure_output_dir
    
    # 创建临时文件
    local temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT
    
    # 提取Luci包
    extract_luci_packages "$CONFIG_FILE" "$temp_file"
    
    # 生成分类报告
    categorize_packages "$temp_file" "$OUTPUT_FILE"
    
    log_info "Luci软件包报告已生成: $OUTPUT_FILE"
    
    # 显示报告内容
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo ""
        echo -e "\033[1;34m========== $STAGE 的Luci软件包报告 ==========\033[0m"
        echo ""
        cat "$OUTPUT_FILE"
        echo ""
    fi
}

# 执行主函数
main "$@"
