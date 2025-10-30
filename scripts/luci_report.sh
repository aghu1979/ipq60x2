#!/bin/bash
# Luci软件包报告脚本
# 功能：生成和显示Luci软件包报告

set -euo pipefail

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 使用说明
usage() {
    echo "用法: $0 <config_file> <output_file>"
    echo "示例: $0 .config luci_report.txt"
    exit 1
}

# 检查参数
if [[ $# -ne 2 ]]; then
    usage
fi

CONFIG_FILE="$1"
OUTPUT_FILE="$2"

# 日志函数
log_info() {
    echo -e "\033[32m[INFO]\033[0m $*"
}

# 提取Luci软件包
extract_luci_packages() {
    local config="$1"
    local output="$2"
    
    # 提取所有Luci包
    grep "^CONFIG_PACKAGE_luci.*=y$" "$config" | \
        sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | \
        sort > "$output"
    
    local count=$(wc -l < "$output")
    log_info "提取到 $count 个Luci软件包"
}

# 分类Luci软件包
categorize_packages() {
    local input_file="$1"
    local output_file="$2"
    
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

EOF
    
    # 按分类统计
    for category in "${!categories[@]}"; do
        local pattern="${categories[$category]}"
        local count=0
        
        echo "## $category" >> "$output_file"
        
        while IFS= read -r pkg; do
            if [[ "$pkg" == $pattern* ]]; then
                echo "  - $pkg" >> "$output_file"
                ((count++))
            fi
        done < "$input_file"
        
        if [[ $count -eq 0 ]]; then
            echo "  无" >> "$output_file"
        else
            echo "  (共 $count 个)" >> "$output_file"
        fi
        
        echo "" >> "$output_file"
    done
    
    # 未分类的包
    echo "## 其他软件包" >> "$output_file"
    local other_count=0
    
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
            ((other_count++))
        fi
    done < "$input_file"
    
    if [[ $other_count -eq 0 ]]; then
        echo "  无" >> "$output_file"
    else
        echo "  (共 $other_count 个)" >> "$output_file"
    fi
}

# 主函数
main() {
    log_info "生成Luci软件包报告..."
    
    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error_exit "配置文件不存在: $CONFIG_FILE"
    fi
    
    # 创建临时文件
    local temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT
    
    # 提取Luci包
    extract_luci_packages "$CONFIG_FILE" "$temp_file"
    
    # 生成分类报告
    categorize_packages "$temp_file" "$OUTPUT_FILE"
    
    log_info "Luci软件包报告已生成: $OUTPUT_FILE"
}

# 执行主函数
main "$@"
