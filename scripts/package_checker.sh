#!/bin/bash

# 加载日志函数
source scripts/logger.sh

# 查找配置文件
find_config_file() {
    local base_name="$1"
    local config_dir="${GITHUB_WORKSPACE}/${CONFIG_BASE_DIR}"
    
    for ext in ".config" ".config.txt"; do
        if [ -f "${config_dir}/${base_name}${ext}" ]; then
            echo "${config_dir}/${base_name}${ext}"
            return 0
        fi
    done
    return 1
}

# 检查配置中的Luci软件包
check_luci_packages() {
    local config_file="$1"
    local step_name="$2"
    
    echo "🔍 $step_name 配置中的 Luci 软件包"
    
    local luci_packages=$(grep -E "^CONFIG_PACKAGE_luci-.+=y" "$config_file" | sort || true)
    
    if [ -n "$luci_packages" ]; then
        local count=$(echo "$luci_packages" | wc -l)
        echo "发现 $count 个 Luci 软件包:"
        echo "$luci_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | tr '\n' ' '
        echo ""
        log "INFO" "$step_name 包含 $count 个 Luci 软件包"
    else
        echo "(无 Luci 软件包)"
        log "INFO" "$step_name 无 Luci 软件包"
    fi
    echo ""
}

# 运行defconfig
run_defconfig() {
    echo "🔧 运行 defconfig"
    log "INFO" "运行 defconfig..."
    
    # 执行defconfig并捕获输出
    if ! make defconfig; then
        echo "❌ defconfig 执行失败!"
        echo "请检查配置文件是否存在语法错误或依赖问题"
        log "ERROR" "defconfig 执行失败"
        exit 1
    fi
    
    echo "✅ defconfig 执行成功"
    log "INFO" "defconfig 执行成功"
    echo ""
}

# 生成软件包对比报告
generate_package_report() {
    local before_packages="$1"
    local step_name="$2"
    
    echo "📊 $step_name 软件包对比报告"
    
    local after_packages=$(grep -E "^CONFIG_PACKAGE_luci-.+=y" .config | sort || true)
    
    # 转换为简单列表
    local before_list=$(echo "$before_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | sort | tr '\n' ' ')
    local after_list=$(echo "$after_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | sort | tr '\n' ' ')
    
    echo "配置前软件包列表:"
    echo "$before_list"
    echo ""
    
    echo "defconfig后软件包列表:"
    echo "$after_list"
    echo ""
    
    # 检查缺失的软件包
    local missing_found=false
    echo "$before_packages" | while read pkg_line; do
        local pkg=$(echo "$pkg_line" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//')
        if ! echo "$after_packages" | grep -Fq "CONFIG_PACKAGE_${pkg}=y"; then
            if [ "$missing_found" = false ]; then
                echo "⚠️ 缺失软件包报告:"
                echo "以下软件包在defconfig后缺失:"
                missing_found=true
            fi
            echo "  ❌ $pkg"
            log "WARN" "缺失软件包: $pkg"
        fi
    done
    
    if [ "$missing_found" = false ]; then
        echo "✅ 无缺失软件包"
        log "INFO" "无缺失软件包"
    else
        echo "注意：缺失的软件包可能是因为依赖不满足或已被移除"
    fi
    
    echo ""
}
