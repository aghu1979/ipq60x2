#!/bin/bash

# 配置合并脚本

merge_configs() {
    local config_base="$1"
    local config_branch="$2"
    
    source "$LOGGER_SCRIPT"
    step_start "MERGE_CONFIG" "合并配置文件"
    
    log "INFO" "合并配置文件..."
    
    # 读取合并前的luci软件包
    LUCI_BEFORE=$(grep "^CONFIG_PACKAGE_luci.*=y" "$config_base" | sort || true)
    
    # 合并配置文件
    cat "$config_base" "$config_branch" > "$OPENWRT_PATH/.config" || {
        log "ERROR" "合并配置文件失败"
        exit 1
    }
    
    # 读取合并后的luci软件包
    LUCI_AFTER=$(grep "^CONFIG_PACKAGE_luci.*=y" "$OPENWRT_PATH/.config" | sort || true)
    
    # 显示合并后的luci软件包
    log "INFO" "=== 合并后的Luci软件包列表 ==="
    if [ -n "$LUCI_AFTER" ]; then
        echo "$LUCI_AFTER" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | while read pkg; do
            log "INFO" "  - $pkg"
        done
    else
        log "INFO" "  (无Luci软件包)"
    fi
    
    # 运行defconfig
    log "INFO" "运行defconfig..."
    cd "$OPENWRT_PATH"
    if make defconfig; then
        log "INFO" "defconfig成功"
    else
        log "ERROR" "defconfig失败"
        exit 1
    fi
    
    # 读取defconfig后的luci软件包
    LUCI_DEFCONFIG=$(grep "^CONFIG_PACKAGE_luci.*=y" "$OPENWRT_PATH/.config" | sort || true)
    
    # 显示defconfig后的luci软件包
    log "INFO" "=== Defconfig后的Luci软件包列表 ==="
    if [ -n "$LUCI_DEFCONFIG" ]; then
        echo "$LUCI_DEFCONFIG" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | while read pkg; do
            log "INFO" "  - $pkg"
        done
    else
        log "INFO" "  (无Luci软件包)"
    fi
    
    # 生成defconfig对比报告并输出到控制台
    log "INFO" "=== Defconfig软件包对比 ==="
    
    # 检查是否有新增的软件包
    NEW_PACKAGES=$(comm -13 <(echo "$LUCI_AFTER") <(echo "$LUCI_DEFCONFIG") | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//')
    if [ -n "$NEW_PACKAGES" ]; then
        log "INFO" "🔍 发现新增的Luci软件包:"
        echo "$NEW_PACKAGES" | while read pkg; do
            log "INFO" "  ✅ $pkg"
            echo "  ✅ $pkg"
        done
    else
        log "INFO" "ℹ️  无新增的Luci软件包"
        echo "  ℹ️  无新增的Luci软件包"
    fi
    
    # 检查是否有缺失的软件包
    MISSING_PACKAGES=$(comm -23 <(echo "$LUCI_AFTER") <(echo "$LUCI_DEFCONFIG") | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//')
    if [ -n "$MISSING_PACKAGES" ]; then
        log "WARN" "⚠️  发现缺失的Luci软件包:"
        echo "$MISSING_PACKAGES" | while read pkg; do
            log "WARN" "  ❌ $pkg"
            echo "  ❌ $pkg"
        done
    else
        log "INFO" "ℹ️  无缺失的Luci软件包"
        echo "  ℹ️  无缺失的Luci软件包"
    fi
    
    echo ""
    
    # 生成defconfig对比报告文件
    {
        echo "## Defconfig后的Luci软件包变化"
        echo ""
        echo "### 新增的Luci软件包:"
        if [ -n "$NEW_PACKAGES" ]; then
            echo "$NEW_PACKAGES" | while read pkg; do
                echo "- ✅ $pkg"
            done
        else
            echo "（无新增软件包）"
        fi
        echo ""
        echo "### 缺失的Luci软件包:"
        if [ -n "$MISSING_PACKAGES" ]; then
            echo "$MISSING_PACKAGES" | while read pkg; do
                echo "- ❌ $pkg"
            done
        else
            echo "（无缺失软件包）"
        fi
        echo ""
    } > "$GITHUB_WORKSPACE/luci_defconfig_report.md"
    
    # 生成合并差异报告
    {
        echo "## Luci软件包合并报告"
        echo ""
        echo "### 新增的Luci软件包:"
        comm -13 <(echo "$LUCI_BEFORE") <(echo "$LUCI_AFTER") | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | while read pkg; do
            echo "- ✅ $pkg"
        done
        echo ""
        echo "### 缺失的Luci软件包:"
        comm -23 <(echo "$LUCI_BEFORE") <(echo "$LUCI_AFTER") | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y//' | while read pkg; do
            echo "- ❌ $pkg"
        done
        echo ""
    } > "$GITHUB_WORKSPACE/luci_report.md"
    
    step_complete "MERGE_CONFIG" "success"
}

# 导出函数
export -f merge_configs
