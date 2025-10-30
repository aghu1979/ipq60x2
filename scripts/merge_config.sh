#!/bin/bash
# 配置合并脚本
# 功能：合并多个配置文件并生成报告

set -euo pipefail

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 使用说明
usage() {
    echo "用法: $0 <base_config> <branch_config> <variant_config> <output_config>"
    echo "示例: $0 base_ipq60xx.config base_immwrt.config Ultra.config .config"
    exit 1
}

# 检查参数
if [[ $# -ne 4 ]]; then
    usage
fi

BASE_CONFIG="$1"
BRANCH_CONFIG="$2"
VARIANT_CONFIG="$3"
OUTPUT_CONFIG="$4"

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

# 检查配置文件是否存在
check_config_files() {
    for config in "$BASE_CONFIG" "$BRANCH_CONFIG" "$VARIANT_CONFIG"; do
        if [[ ! -f "$config" ]]; then
            log_error "配置文件不存在: $config"
            exit 1
        fi
    done
}

# 清理配置文件（移除注释和空行）
clean_config() {
    local input="$1"
    local output="$2"
    
    log_info "清理配置文件: $(basename "$input")"
    
    # 检查输入文件是否存在且可读
    if [[ ! -f "$input" ]]; then
        log_error "输入文件不存在: $input"
        return 1
    fi
    
    # 过滤掉注释行和空行，只保留有效的配置项
    # 使用更稳健的方式处理文件
    if grep -q . "$input" 2>/dev/null; then
        grep -E '^[^#].*=.*$' "$input" 2>/dev/null | \
            sed 's/^[[:space:]]*//' | \
            sed 's/[[:space:]]*$//' | \
            grep -v '^$' | \
            sort -u > "$output" 2>/dev/null || {
            log_error "处理配置文件失败: $input"
            return 1
        }
    else
        log_error "文件为空或无法读取: $input"
        return 1
    fi
    
    # 检查输出文件
    if [[ ! -f "$output" ]]; then
        log_error "生成输出文件失败: $output"
        return 1
    fi
    
    local count=$(wc -l < "$output" 2>/dev/null || echo "0")
    log_info "从 $(basename "$input") 提取了 $count 个有效配置项"
}

# 合并配置文件
merge_configs() {
    log_info "开始合并配置文件..."
    
    # 创建临时文件
    local temp_config=$(mktemp)
    local clean_base=$(mktemp)
    local clean_branch=$(mktemp)
    local clean_variant=$(mktemp)
    
    # 设置清理陷阱
    trap "rm -f $temp_config $clean_base $clean_branch $clean_variant" EXIT
    
    # 清理各个配置文件
    log_info "清理配置文件中的注释和空行..."
    
    if ! clean_config "$BASE_CONFIG" "$clean_base"; then
        log_error "清理基础配置失败"
        exit 1
    fi
    
    if ! clean_config "$BRANCH_CONFIG" "$clean_branch"; then
        log_error "清理分支配置失败"
        exit 1
    fi
    
    if ! clean_config "$VARIANT_CONFIG" "$clean_variant"; then
        log_error "清理变体配置失败"
        exit 1
    fi
    
    # 按顺序合并配置
    cat "$clean_base" > "$temp_config"
    log_info "已加载基础配置: $BASE_CONFIG"
    
    cat "$clean_branch" >> "$temp_config"
    log_info "已加载分支配置: $BRANCH_CONFIG"
    
    cat "$clean_variant" >> "$temp_config"
    log_info "已加载变体配置: $VARIANT_CONFIG"
    
    # 去重并排序
    sort -u "$temp_config" > "$OUTPUT_CONFIG"
    
    # 验证输出文件
    if [[ ! -f "$OUTPUT_CONFIG" ]]; then
        log_error "生成合并配置失败"
        exit 1
    fi
    
    local final_count=$(wc -l < "$OUTPUT_CONFIG" 2>/dev/null || echo "0")
    log_info "配置合并完成: $OUTPUT_CONFIG (共 $final_count 个配置项)"
    
    # 清理临时文件
    rm -f "$temp_config" "$clean_base" "$clean_branch" "$clean_variant"
    trap - EXIT
}

# 提取Luci软件包
extract_luci_packages() {
    local config_file="$1"
    local output_file="$2"
    
    # 检查配置文件是否存在
    if [[ ! -f "$config_file" ]]; then
        log_warn "配置文件不存在: $config_file"
        touch "$output_file"
        return 0
    fi
    
    log_info "提取Luci软件包列表..."
    
    # 提取所有以=y结尾的luci配置
    if grep -q "^CONFIG_PACKAGE_luci.*=y$" "$config_file" 2>/dev/null; then
        grep "^CONFIG_PACKAGE_luci.*=y$" "$config_file" 2>/dev/null | \
            sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | \
            sort > "$output_file" 2>/dev/null || {
            log_warn "提取Luci软件包失败"
            touch "$output_file"
        }
        
        local count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
        log_info "找到 $count 个Luci软件包"
    else
        log_warn "未找到Luci软件包配置"
        touch "$output_file"
    fi
}

# 生成差异报告
generate_diff_report() {
    local before_file="$1"
    local after_file="$2"
    local report_file="$3"
    
    log_info "生成Luci软件包差异报告..."
    
    # 检查文件是否存在
    [[ ! -f "$before_file" ]] && touch "$before_file"
    [[ ! -f "$after_file" ]] && touch "$after_file"
    
    # 创建报告文件
    cat > "$report_file" << 'EOF'
# Luci软件包差异报告

## 统计信息
EOF
    
    # 计算统计信息
    local before_count=$(wc -l < "$before_file" 2>/dev/null || echo "0")
    local after_count=$(wc -l < "$after_file" 2>/dev/null || echo "0")
    local added_count=$(comm -13 "$before_file" "$after_file" 2>/dev/null | wc -l || echo "0")
    local removed_count=$(comm -23 "$before_file" "$after_file" 2>/dev/null | wc -l || echo "0")
    
    cat >> "$report_file" << EOF
- 合并前Luci包数量: $before_count
- 合并后Luci包数量: $after_count
- 新增Luci包数量: $added_count
- 移除Luci包数量: $removed_count

## 新增的Luci软件包
EOF
    
    # 列出新增的包
    if [[ $added_count -gt 0 ]]; then
        comm -13 "$before_file" "$after_file" 2>/dev/null | while read -r pkg; do
            echo "  + $pkg" >> "$report_file"
        done
    else
        echo "  无新增包" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## 移除的Luci软件包
EOF
    
    # 列出移除的包
    if [[ $removed_count -gt 0 ]]; then
        comm -23 "$before_file" "$after_file" 2>/dev/null | while read -r pkg; do
            echo "  - $pkg" >> "$report_file"
        done
    else
        echo "  无移除包" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## 完整的Luci软件包列表
EOF
    
    # 列出所有包
    if [[ -s "$after_file" ]]; then
        cat "$after_file" | while read -r pkg; do
            echo "  * $pkg" >> "$report_file"
        done
    else
        echo "  无Luci软件包" >> "$report_file"
    fi
    
    log_info "差异报告已生成: $report_file"
}

# 高亮显示报告
highlight_report() {
    local report_file="$1"
    
    # 检查报告文件是否存在
    if [[ ! -f "$report_file" ]]; then
        log_warn "报告文件不存在: $report_file"
        return
    fi
    
    log_info "显示Luci软件包报告（高亮模式）："
    echo ""
    
    # 使用颜色高亮显示
    while IFS= read -r line; do
        if [[ $line =~ ^\s*\+ ]]; then
            echo -e "\033[32m$line\033[0m"  # 绿色显示新增
        elif [[ $line =~ ^\s*- ]]; then
            echo -e "\033[31m$line\033[0m"  # 红色显示移除
        elif [[ $line =~ ^## ]]; then
            echo -e "\033[34m$line\033[0m"  # 蓝色显示标题
        elif [[ $line =~ ^- ]]; then
            echo -e "\033[33m$line\033[0m"  # 黄色显示统计
        else
            echo "$line"
        fi
    done < "$report_file"
    
    echo ""
}

# 验证配置
validate_config() {
    local config_file="$1"
    
    log_info "验证配置文件..."
    
    # 检查是否有语法错误
    if [[ -f "$config_file" ]]; then
        local config_count=$(grep -c "^CONFIG_.*=" "$config_file" 2>/dev/null || echo "0")
        log_info "配置文件包含 $config_count 个配置项"
        
        # 检查关键配置
        local key_configs=(
            "CONFIG_TARGET_ARCH"
            "CONFIG_TARGET_BOARD"
            "CONFIG_TARGET_SUBTARGET"
        )
        
        for config in "${key_configs[@]}"; do
            if grep -q "^${config}=" "$config_file" 2>/dev/null; then
                local value=$(grep "^${config}=" "$config_file" 2>/dev/null | cut -d'=' -f2)
                log_info "找到关键配置: $config=$value"
            else
                log_warn "缺少关键配置: $config"
            fi
        done
    else
        log_warn "配置文件不存在: $config_file"
    fi
}

# 主函数
main() {
    log_info "开始配置合并流程..."
    
    # 检查输入文件
    check_config_files
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # 保存合并前的Luci包列表（如果输出配置已存在）
    local before_luci="$temp_dir/luci_before.txt"
    if [[ -f "$OUTPUT_CONFIG" ]]; then
        extract_luci_packages "$OUTPUT_CONFIG" "$before_luci"
    else
        touch "$before_luci"
    fi
    
    # 备份旧配置（如果存在）
    if [[ -f "$OUTPUT_CONFIG" ]]; then
        cp "$OUTPUT_CONFIG" "${OUTPUT_CONFIG}.backup"
        log_info "已备份旧配置到 ${OUTPUT_CONFIG}.backup"
    fi
    
    # 合并配置文件
    merge_configs
    
    # 验证配置
    validate_config "$OUTPUT_CONFIG"
    
    # 保存合并后的Luci包列表
    local after_luci="$temp_dir/luci_after.txt"
    extract_luci_packages "$OUTPUT_CONFIG" "$after_luci"
    
    # 生成差异报告
    local report_file="${OUTPUT_CONFIG}.luci_report.md"
    generate_diff_report "$before_luci" "$after_luci" "$report_file"
    
    # 高亮显示报告
    highlight_report "$report_file"
    
    log_info "配置合并流程完成"
}

# 执行主函数
main "$@"
