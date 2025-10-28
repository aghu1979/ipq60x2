#!/bin/bash

# 加载日志函数
source /tmp/log_functions.sh

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
    
    echo ""
    echo "=================================================================================="
    echo -e "\033[1;44;37m 🔍 检查 $step_name 配置中的 Luci 软件包 \033[0m"
    echo "=================================================================================="
    echo -e "\033[1;36m配置文件: $config_file\033[0m"
    echo ""
    
    local luci_packages=$(grep -E "^CONFIG_PACKAGE_luci-.+=y" "$config_file" | sort || true)
    
    if [ -n "$luci_packages" ]; then
        echo -e "\033[1;32m发现以下 Luci 软件包:\033[0m"
        echo "$luci_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | while read pkg; do
            echo -e "  \033[0;32m✓ $pkg\033[0m"
            log "INFO" "  - $pkg"
        done
    else
        echo -e "\033[1;33m(无 Luci 软件包)\033[0m"
        log "INFO" "  (无 Luci 软件包)"
    fi
    echo "=================================================================================="
    echo ""
}

# 运行defconfig并检查软件包变化
check_defconfig_packages() {
    local before_packages="$1"
    local step_name="$2"
    
    echo ""
    echo "=================================================================================="
    echo -e "\033[1;44;37m 🔧 运行 defconfig 并检查 $step_name \033[0m"
    echo "=================================================================================="
    log "INFO" "运行 defconfig..."
    
    # 执行defconfig并捕获输出
    DEFCONFIG_OUTPUT=$(make defconfig 2>&1)
    DEFCONFIG_EXIT_CODE=$?
    
    # 检查defconfig是否成功
    if [ $DEFCONFIG_EXIT_CODE -ne 0 ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!!! 致命错误: 'make defconfig' 执行失败!"
        echo "!!! 退出码: $DEFCONFIG_EXIT_CODE"
        echo "!!! 错误信息如下:"
        echo "$DEFCONFIG_OUTPUT"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        exit 1
    fi
    
    echo -e "\033[1;36mDefconfig 完成，正在分析软件包变化...\033[0m"
    echo ""
    
    local after_packages=$(grep -E "^CONFIG_PACKAGE_luci-.+=y" .config | sort || true)
    
    echo -e "\033[1;32mDefconfig后的最终 Luci 软件包列表:\033[0m"
    if [ -n "$after_packages" ]; then
        echo "$after_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | while read pkg; do
            echo -e "  \033[0;32m✓ $pkg\033[0m"
            log "INFO" "  - $pkg"
        done
    else
        echo -e "\033[1;33m(无 Luci 软件包)\033[0m"
        log "INFO" "  (无 Luci 软件包)"
    fi
    
    # 分析软件包变化
    analyze_package_changes "$before_packages" "$after_packages"
    
    echo "=================================================================================="
    echo ""
}

# 分析软件包变化
analyze_package_changes() {
    local before_packages="$1"
    local after_packages="$2"
    
    echo ""
    echo -e "\033[1;34m------------------- 软件包变化分析 -------------------\033[0m"
    
    # 检查新增的软件包
    local found_new=false
    echo "$after_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | while read pkg; do
        if ! echo "$before_packages" | grep -Fq "CONFIG_PACKAGE_${pkg}=y"; then
            if [ "$found_new" = false ]; then
                echo -e "\033[1;32m🔍 发现新增的 Luci 软件包:\033[0m"
                found_new=true
            fi
            echo -e "  \033[0;32m✅ $pkg\033[0m"
            log "INFO" "  ✅ $pkg"
        fi
    done
    
    if [ "$found_new" = false ]; then
        echo -e "\033[1;37mℹ️  无新增的 Luci 软件包\033[0m"
        log "INFO" "ℹ️  无新增的Luci软件包"
    fi
    
    echo ""
    
    # 检查缺失的软件包
    local found_missing=false
    echo "$before_packages" | while read pkg_line; do
        local pkg=$(echo "$pkg_line" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//')
        if ! echo "$after_packages" | grep -Fq "CONFIG_PACKAGE_${pkg}=y"; then
            if [ "$found_missing" = false ]; then
                echo -e "\033[1;31m⚠️  发现缺失的 Luci 软件包:\033[0m"
                found_missing=true
            fi
            echo -e "  \033[0;31m❌ $pkg\033[0m"
            log "WARN" "  ❌ $pkg"
        fi
    done
    
    if [ "$found_missing" = false ]; then
        echo -e "\033[1;37mℹ️  无缺失的 Luci 软件包\033[0m"
        log "INFO" "ℹ️  无缺失的Luci软件包"
    else
        echo -e "\n\033[1;31m注意：缺失的软件包可能是因为依赖不满足或已被移除\033[0m"
    fi
}

# 导出函数
export -f find_config_file check_luci_packages check_defconfig_packages analyze_package_changes
