#!/bin/bash

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

# 检查配置中的Luci软件包（简化版）
check_luci_packages() {
    local config_file="$1"
    local step_name="$2"
    
    echo -e "\033[1;44;37m 🔍 $step_name 配置中的 Luci 软件包 \033[0m"
    
    local luci_packages=$(grep -E "^CONFIG_PACKAGE_luci-.+=y" "$config_file" | sort || true)
    
    if [ -n "$luci_packages" ]; then
        local count=$(echo "$luci_packages" | wc -l)
        echo -e "\033[1;32m发现 $count 个 Luci 软件包:\033[0m"
        echo "$luci_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | tr '\n' ' '
        echo ""
        log "INFO" "$step_name 包含 $count 个 Luci 软件包"
    else
        echo -e "\033[1;33m(无 Luci 软件包)\033[0m"
        log "INFO" "$step_name 无 Luci 软件包"
    fi
    echo ""
}

# 运行defconfig（单独步骤）
run_defconfig() {
    echo -e "\033[1;44;37m 🔧 运行 defconfig \033[0m"
    log "INFO" "运行 defconfig..."
    
    # 执行defconfig并捕获输出
    DEFCONFIG_OUTPUT=$(make defconfig 2>&1)
    DEFCONFIG_EXIT_CODE=$?
    
    # 检查defconfig是否成功
    if [ $DEFCONFIG_EXIT_CODE -ne 0 ]; then
        echo -e "\033[1;41;37m❌ defconfig 执行失败!\033[0m"
        echo -e "\033[1;31m退出码: $DEFCONFIG_EXIT_CODE\033[0m"
        echo -e "\033[1;31m错误信息:\033[0m"
        echo "$DEFCONFIG_OUTPUT"
        echo ""
        echo -e "\033[1;31m请检查配置文件是否存在语法错误或依赖问题\033[0m"
        
        # 记录到日志
        log "ERROR" "defconfig 执行失败，退出码: $DEFCONFIG_EXIT_CODE"
        echo "$DEFCONFIG_OUTPUT" | while read line; do
            log "ERROR" "$line"
        done
        
        exit $DEFCONFIG_EXIT_CODE
    fi
    
    echo -e "\033[1;32m✅ defconfig 执行成功\033[0m"
    log "INFO" "defconfig 执行成功"
    echo ""
}

# 生成软件包对比报告（简化版）
generate_package_report() {
    local before_packages="$1"
    local step_name="$2"
    
    echo -e "\033[1;44;37m 📊 $step_name 软件包对比报告 \033[0m"
    
    local after_packages=$(grep -E "^CONFIG_PACKAGE_luci-.+=y" .config | sort || true)
    
    # 转换为简单列表
    local before_list=$(echo "$before_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | sort | tr '\n' ' ')
    local after_list=$(echo "$after_packages" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | sort | tr '\n' ' ')
    
    echo -e "\033[1;36m配置前软件包列表:\033[0m"
    echo "$before_list"
    echo ""
    
    echo -e "\033[1;36mdefconfig后软件包列表:\033[0m"
    echo "$after_list"
    echo ""
    
    # 检查缺失的软件包
    local missing_packages=""
    echo "$before_packages" | while read pkg_line; do
        local pkg=$(echo "$pkg_line" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//')
        if ! echo "$after_packages" | grep -Fq "CONFIG_PACKAGE_${pkg}=y"; then
            if [ -z "$missing_packages" ]; then
                missing_packages="$pkg"
            else
                missing_packages="$missing_packages $pkg"
            fi
        fi
    done
    
    # 生成缺失报告
    if [ -n "$missing_packages" ]; then
        echo -e "\033[1;41;37m⚠️ 缺失软件包报告:\033[0m"
        echo -e "\033[1;31m以下软件包在defconfig后缺失:\033[0m"
        
        # 高亮显示每个缺失的软件包
        for pkg in $missing_packages; do
            echo -e "  \033[1;31m❌ $pkg\033[0m"
            log "WARN" "缺失软件包: $pkg"
        done
        
        echo ""
        echo -e "\033[1;33m注意：缺失的软件包可能是因为依赖不满足或已被移除\033[0m"
    else
        echo -e "\033[1;32m✅ 无缺失软件包\033[0m"
        log "INFO" "无缺失软件包"
    fi
    
    echo ""
}

# 导出函数
export -f find_config_file check_luci_packages run_defconfig generate_package_report
