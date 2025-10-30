#!/bin/bash
# 配置合并脚本
# 功能：合并多个配置文件并生成报告

# 完全不使用 set -euo pipefail，避免管道错误导致脚本退出
set -e

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
    
    # 检查文件是否为空
    if [[ ! -s "$input" ]]; then
        log_warn "配置文件为空: $input"
        touch "$output"
        return 0
    fi
    
    # 创建输出文件
    if ! touch "$output" 2>/dev/null; then
        log_error "无法创建输出文件: $output"
        return 1
    fi
    
    # 过滤掉注释行和空行，只保留有效的配置项
    local temp_file
    temp_file=$(mktemp) || {
        log_error "无法创建临时文件"
        exit 1
    }
    trap "rm -f $temp_file" EXIT
    
    # 首先尝试提取有效的配置行
    if grep -E '^[^#].*=.*$' "$input" > "$temp_file" 2>/dev/null; then
        # 处理提取的行：去除首尾空格，过滤空行
        sed -i 's/^[[:space:]]*//' "$temp_file"
        sed -i 's/[[:space:]]*$//' "$temp_file"
        grep -v '^$' "$temp_file" | sort -u > "$output" 2>/dev/null || {
            log_warn "处理配置文件时出现问题: $input"
            # 如果处理失败，至少保留原始的有效行
            cp "$temp_file" "$output"
        }
    else
        log_warn "未找到有效的配置行: $input"
        touch "$output"
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
    
    # 检查输出文件
    if [[ ! -f "$output" ]]; then
        log_error "生成输出文件失败: $output"
        return 1
    fi
    
    local count
    count=$(cat "$output" 2>/dev/null | wc -l || echo "0"
    if [[ $count -gt 0 ]]; then
        log_info "从 $(basename "$input") 提取了 $count 个有效配置项"
    else
        log_warn "从 $(basename "$input") 未提取到有效配置项"
    fi
}

# 合并配置文件
merge_configs() {
    log_info "开始合并配置文件..."
    
    # 创建临时文件
    local temp_config
    temp_config=$(mktemp) || {
        log_error "无法创建临时文件"
        exit 1
    }
    local clean_base
    clean_base=$(mktemp) || {
        log_error "无法创建临时文件"
        rm -f "$temp_config" "$clean_base" "$clean_branch" "$clean_variant" "$clean_variant"
        exit 1
    }
    
    # 设置清理陷阱
    trap "rm -f $temp_config $clean_base $clean_branch $clean_variant" EXIT
    
    # 清理各个配置文件
    log_info "清理配置文件中的注释和空行..."
    
    if ! clean_config "$BASE_CONFIG" "$clean_base"; then
        log_error "清理基础配置失败"
        rm -f "$temp_config" "$clean_base" "$clean_branch" "$clean_variant"
        exit 1
    fi
    
    if ! clean_config "$BRANCH_CONFIG" "$clean_branch"; then
        log_error "清理分支配置失败"
        rm -f "$temp_config" "$clean_base" "$clean_branch" "$clean_variant"
        exit 1
    fi
    
    if ! clean_config "$VARIANT_CONFIG" "$clean_variant"; then
        log_error "清理变体配置失败"
        rm -f "$temp_config" "$clean_base" "$clean_branch" "$clean_variant"
        exit 1
    fi
    
    # 按顺序合并配置
    if [[ -s "$clean_base" ]]; then
        cat "$clean_base" > "$temp_config"
        log_info "已加载基础配置: $BASE_CONFIG"
    else
        log_warn "基础配置为空: $BASE_CONFIG"
        touch "$temp_config"
    fi
    
    if [[ -s "$clean_branch" ]]; then
        cat "$clean_branch" >> "$temp_config"
        log_info "已加载分支配置: $BRANCH_CONFIG"
    else
        log_warn "分支配置为空: $BRANCH_CONFIG"
    fi
    
    if [[ -s "$clean_variant" ]]; then
        cat "$clean_variant" >> "$temp_config"
        log_info "已加载变体配置: $VARIANT_CONFIG"
    else
        log_warn "变体配置为空: $VARIANT_CONFIG"
    fi
    
    # 基去重并排序
    if [[ -s "$temp_config" ]]; then
        sort -u "$temp_config" > "$OUTPUT_CONFIG"
    else
        log_warn "所有配置文件都为空，创建空配置"
        touch "$OUTPUT_CONFIG"
    fi
    
    # 验证输出文件
    if [[ ! -f "$OUTPUT_CONFIG" ]]; then
        log_error "生成合并配置失败"
        rm -f "$temp_config" "$clean_base" "$clean_branch" "$clean_variant"
        exit 1
    fi
    
    local final_count
    final_count=$(cat "$OUTPUT_CONFIG" 2>/dev/null | wc -l || echo "0"
    log_info "配置合并完成: $OUTPUT_CONFIG (共 $final_count 个配置项)"
    
    # 清理临时文件
    rm -f "$temp_config" "$clean_base" "$clean_branch" "$clean_variant" EXIT
    
    # 验证配置
    validate_config "$OUTPUT_CONFIG"
    
    log_info "配置合并流程完成"
    log_info "接下来请运行 make defconfig 来处理依赖关系"
    log_info "defconfig后，请运行 luci_report.sh 生成对比报告"
}

# 验证配置
validate_config() {
    local config_file="$1"
    
    log_info "验证配置文件..."
    
    # 检查是否有语法错误
    if [[ -f "$config_file" ]]; then
        local config_count
        config_count=$(grep -c "^CONFIG_.*=" "$config_file" 2>/dev/null | wc -l || echo "0"
        log_info "配置文件包含 $config_count 个配置项"
        
        # 检查关键配置
        local key_configs=(
            "CONFIG_TARGET_ARCH"
            "CONFIG_TARGET_BOARD"
            "CONFIG_TARGET_SUBTARGET"
        )
        
        for config in "${key_configs[@]}"; do
            if grep -q "^${config}=" "$config_file" 2>/dev/null; then
                local value
                value=$(grep "^${config}=" "$config_file" 2>/dev/null | cut -d'=' -f2)
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
    local temp_dir
    temp_dir=$(mktemp -d || {
        log_error "无法创建临时目录"
        exit 1
    }
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
    
    # 保存合并后的Luci包列表（defconfig前）
    local merged_luci="$temp_dir/luci_merged.txt"
    extract_luci_packages "$OUTPUT_CONFIG" "$merged_luci"
    
    # 生成合并阶段的报告
    local merge_report="${OUTPUT_CONFIG}.merge_report.md"
    generate_diff_report "$before_luci" "$merged_luci" "$merge_report"
    
    log_info "配置合并流程完成"
    log_info "接下来请运行 make defconfig 来处理依赖关系"
    log_info "defconfig后，请运行 luci_report.sh 生成对比报告"
}

# 执行主函数
main "$@"
