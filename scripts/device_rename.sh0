#!/bin/bash
# 设备重命名脚本
# 功能：根据设备名称重命名固件文件

set -euo pipefail

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 使用说明
usage() {
    echo "用法: $0 <source_dir> <device_name> <new_name_prefix>"
    echo "示例: $0 output/ultra-immwrt jdcloud_re-ss-01 IPQ60xx-Firmware"
    exit 1
}

# 检查参数
if [[ $# -ne 3 ]]; then
    usage
fi

SOURCE_DIR="$1"
DEVICE_NAME="$2"
NEW_PREFIX="$3"

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

# 检查源目录
check_source_dir() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        error_exit "源目录不存在: $SOURCE_DIR"
    fi
}

# 获取固件文件列表
get_firmware_files() {
    local device="$1"
    local temp_file=$(mktemp)
    
    # 查找所有包含设备名称的固件文件
    find "$SOURCE_DIR" -type f \( -name "*${device}*" -o -name "*generic*" \) \
        \( -name "*.bin" -o -name "*.img" -o -name "*.tar" \) \
        > "$temp_file"
    
    echo "$temp_file"
}

# 重命名固件文件
rename_firmware() {
    local file="$1"
    local device="$2"
    local prefix="$3"
    
    # 获取文件扩展名
    local ext="${file##*.}"
    local base_name=$(basename "$file" "$ext")
    
    # 构建新文件名
    local new_name="${prefix}.${ext}"
    
    # 如果是sysupgrade文件，添加标识
    if [[ "$base_name" =~ sysupgrade ]]; then
        new_name="${prefix}-sysupgrade.${ext}"
    fi
    
    # 如果是factory文件，添加标识
    if [[ "$base_name" =~ factory ]]; then
        new_name="${prefix}-factory.${ext}"
    fi
    
    # 执行重命名
    local new_path="$(dirname "$file")/$new_name"
    mv "$file" "$new_path"
    
    log_info "重命名: $(basename "$file") -> $new_name"
}

# 生成校验和
generate_checksums() {
    local dir="$1"
    local checksum_file="$dir/checksums.sha256"
    
    log_info "生成校验和文件..."
    
    cd "$dir"
    sha256sum *.bin *.img *.tar 2>/dev/null > "$checksum_file" || true
    cd - > /dev/null
    
    log_info "校验和文件已生成: $checksum_file"
}

# 生成设备信息文件
generate_device_info() {
    local dir="$1"
    local device="$2"
    local info_file="$dir/device_info.json"
    
    log_info "生成设备信息文件..."
    
    cat > "$info_file" << EOF
{
    "device_name": "$device",
    "build_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "firmware_files": [
EOF
    
    # 列出所有固件文件
    local first=true
    for file in "$dir"/*.bin "$dir"/*.img "$dir"/*.tar 2>/dev/null; do
        if [[ -f "$file" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo "," >> "$info_file"
            fi
            local filename=$(basename "$file")
            local filesize=$(stat -c%s "$file")
            local checksum=$(sha256sum "$file" | awk '{print $1}')
            
            cat >> "$info_file" << EOF
        {
            "filename": "$filename",
            "size": $filesize,
            "sha256": "$checksum"
        }
EOF
        fi
    done
    
    cat >> "$info_file" << EOF
    ]
}
EOF
    
    log_info "设备信息文件已生成: $info_file"
}

# 主函数
main() {
    log_info "开始设备重命名流程..."
    
    # 检查源目录
    check_source_dir
    
    # 获取固件文件列表
    local firmware_list=$(get_firmware_files "$DEVICE_NAME")
    local file_count=$(wc -l < "$firmware_list")
    
    if [[ $file_count -eq 0 ]]; then
        log_warn "未找到设备 $DEVICE_NAME 的固件文件"
        exit 0
    fi
    
    log_info "找到 $file_count 个固件文件"
    
    # 重命名每个文件
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            rename_firmware "$file" "$DEVICE_NAME" "$NEW_PREFIX"
        fi
    done < "$firmware_list"
    
    # 清理临时文件
    rm -f "$firmware_list"
    
    # 生成校验和
    generate_checksums "$SOURCE_DIR"
    
    # 生成设备信息
    generate_device_info "$SOURCE_DIR" "$DEVICE_NAME"
    
    log_info "设备重命名完成"
}

# 执行主函数
main "$@"
