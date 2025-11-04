#!/bin/bash

# --- 脚本运行环境设置 ---
# 遇到错误时立即退出
set -e
# 使用未定义的变量时报错
set -u
# 管道中任何一个命令失败，整个管道就失败
set -o pipefail

# --- 配置区域 ---
# 需要添加的自定义软件源列表
# 格式: "软件源名称;Git仓库地址;分支"
FEEDS_LIST=(
    "passwall-packages;https://github.com/xiaorouji/openwrt-passwall-packages;main"
    "passwall;https://github.com/xiaorouji/openwrt-passwall;main"
    "passwall2;https://github.com/xiaorouji/openwrt-passwall2;main"
    "adguardhome;https://github.com/rufengsuixing/luci-app-adguardhome;master"
    "ddns-go;https://github.com/sirpdboy/luci-app-ddns-go;main"
    "netdata;https://github.com/sirpdboy/luci-app-netdata;main"
    "netspeedtest;https://github.com/sirpdboy/luci-app-netspeedtest;main"
    "partexp;https://github.com/sirpdboy/luci-app-partexp;main"
    "taskplan;https://github.com/sirpdboy/luci-app-taskplan;main"
    "lucky;https://github.com/sirpdboy/luci-app-lucky;main"
    "easytier;https://github.com/sirpdboy/luci-app-easytier;main"
    "homeproxy;https://github.com/immortalwrt/homeproxy;main"
    "packages_lang_golang;https://github.com/sbwml/packages_lang_golang;main"
    "openlist2;https://github.com/sbwml/openlist2;main"
    "mosdns;https://github.com/sbwml/mosdns;main"
    "quickfile;https://github.com/destan19/OpenAppFilter;main"
    "momo;https://github.com/destan19/momo;main"
    "nikki;https://github.com/destan19/nikki;main"
    "OpenAppFilter;https://github.com/destan19/OpenAppFilter;main"
    "openclash;https://github.com/vernesong/OpenClash;master"
    "tailscale;https://github.com/asdfuge/luci-app-tailscale;main"
    "vnt;https://github.com/zhongfly/luci-app-vnt;main"
    "small-package;https://github.com/kenzok8/small-package;main"
    "athena-led;https://github.com/sirpdboy/luci-app-athena-led;main" # 这个软件源已知会失败
)

# --- 函数定义区域 ---

# 函数: 将自定义软件源添加到 feeds.conf.default 文件
add_feeds() {
    echo "================================================"
    echo "第三方软件源集成摘要"
    echo "================================================"
    
    local feeds_conf="feeds.conf.default"
    local success_list=() # 用于存储成功添加的软件源名称
    local failure_list=() # 用于存储添加失败的软件源名称
    local total_processed=0

    # 备份原始的 feeds.conf.default 文件
    cp "$feeds_conf" "${feeds_conf}.bak"

    # 遍历所有预定义的软件源
    for feed_entry in "${FEEDS_LIST[@]}"; do
        # 解析每一行: 名称, URL, 分支
        IFS=';' read -r name url branch <<< "$feed_entry"
        local feed_line="src-git $name $url $branch"
        total_processed=$((total_processed + 1))

        echo "正在处理: $name"
        
        # 检查软件源是否已存在，避免重复添加
        if grep -q "src-git $name " "$feeds_conf"; then
            echo "  -> 软件源 '$name' 已存在，跳过。"
            continue
        fi

        # 验证 Git 仓库是否可访问
        if ! git ls-remote --exit-code "$url" > /dev/null 2>&1; then
            echo "  -> 错误: 无法访问仓库 $url"
            failure_list+=("$name")
            continue
        fi

        # 将软件源信息追加到 feeds.conf.default 文件
        echo "$feed_line" >> "$feeds_conf"
        if [ $? -eq 0 ]; then
            echo "  -> 成功添加软件源 '$name'。"
            success_list+=("$name")
        else
            echo "  -> 失败: 添加软件源 '$name' 到文件时出错。"
            failure_list+=("$name")
        fi
    done

    # 打印处理结果摘要
    echo "================================================"
    echo "总计处理软件包: $total_processed"
    echo "成功添加: ${#success_list[@]}"
    # --- 错误修正: 正确报告失败的数量 ---
    # 原脚本错误地使用了 $total_processed，这里修正为失败列表的长度
    echo "添加失败: ${#failure_list[@]}"
    echo "================================================"

    if [ ${#success_list[@]} -gt 0 ]; then
        echo "成功添加的软件源:"
        for repo in "${success_list[@]}"; do
            echo "  - $repo"
        done
    fi

    if [ ${#failure_list[@]} -gt 0 ]; then
        echo "添加失败的软件源:"
        for repo in "${failure_list[@]}"; do
            echo "  - $repo"
        done
    fi
    echo "================================================"
    
    # 将成功添加的软件源列表通过全局变量传递给主函数
    SUCCESS_FEEDS=("${success_list[@]}")
}

# 函数: 更新并安装所有 feeds
update_and_install_feeds() {
    echo "📦 正在更新所有 feeds..."
    ./scripts/feeds update -a # 从所有配置的软件源下载最新的软件包索引
    echo "📦 正在安装所有 feeds..."
    ./scripts/feeds install -a # 根据索引安装所有软件包到构建环境中
    echo "✅ Feeds 更新与安装完成。"
}

# 函数: 将指定的软件包添加到 .config 配置文件中
configure_packages() {
    local packages_to_add=("$@")
    if [ ${#packages_to_add[@]} -eq 0 ]; then
        echo "🔧 没有需要配置的软件包。"
        return
    fi

    echo "🔧 正在将成功添加的软件包写入 .config..."
    # 在修改前备份 .config 文件，用于后续生成变更报告
    cp .config .config.pre-repo-sh

    # 遍历所有成功添加的软件包，并将其配置项写入 .config
    for pkg_name in "${packages_to_add[@]}"; do
        # 添加所有类型的包，不仅仅是 luci-app-*
        echo "CONFIG_PACKAGE_$pkg_name=y" >> .config
    done
    echo "✅ 已将 ${#packages_to_add[@]} 个软件包添加到 .config。"
}

# 函数: 生成 LUCI 软件包的变更报告
generate_luci_report() {
    echo "📄 正在生成 LUCI 软件包变更报告..."
    
    local config_before=".config.pre-repo-sh" # 脚本修改前的配置文件
    local config_after=".config"             # 脚本修改后的配置文件

    if [ ! -f "$config_before" ]; then
        echo "错误: 找不到备份的配置文件 $config_before，无法生成报告。"
        return
    fi

    # 从前后两个配置文件中提取 LUCI 应用包的配置行，并排序
    grep "^CONFIG_PACKAGE_luci-app" "$config_before" | sort > /tmp/luci_before.txt
    grep "^CONFIG_PACKAGE_luci-app" "$config_after" | sort > /tmp/luci_after.txt

    # 使用 comm 命令比较两个文件，找出新增和移除的包
    local added_pkgs=$(comm -13 /tmp/luci_before.txt /tmp/luci_after.txt | sed 's/^CONFIG_PACKAGE_//g' | sed 's/=y$//g')
    local removed_pkgs=$(comm -23 /tmp/luci_before.txt /tmp/luci_after.txt | sed 's/^CONFIG_PACKAGE_//g' | sed 's/=y$//g')

    # 打印格式化的报告
    echo "=================================================="
    echo "|\033[1;93mLUCI 软件包变更报告 - $(date '+%Y-%m-%d %H:%M:%S')\033[1;97m|"
    echo "=================================================="
    echo "--- 1. 基准配置 (脚本修改前) ---"
    if [ -s /tmp/luci_before.txt ]; then
        grep "^CONFIG_PACKAGE_luci-app" "$config_before" | sed 's/^CONFIG_PACKAGE_/  ▸ /g' | sed 's/=y$//g'
    else
        echo "  (列表为空)"
    fi
    echo "--- 2. 当前配置 (脚本修改后) ---"
    if [ -s /tmp/luci_after.txt ]; then
        grep "^CONFIG_PACKAGE_luci-app" "$config_after" | sed 's/^CONFIG_PACKAGE_/  ▸ /g' | sed 's/=y$//g'
    else
        echo "  (列表为空)"
    fi
    echo "--- 3. 变更摘要 ---"
    if [ -n "$added_pkgs" ]; then
        echo "🎉 新增的软件包 ($(echo "$added_pkgs" | wc -l) 个)"
        echo "$added_pkgs" | sed 's/^/  ✅ /'
    else
        echo "🎉 没有新增的软件包。"
    fi
    if [ -n "$removed_pkgs" ]; then
        echo "🗑️  移除的软件包 ($(echo "$removed_pkgs" | wc -l) 个)"
        echo "$removed_pkgs" | sed 's/^/  ❌ /'
    else
        echo "🗑️  没有移除的软件包。"
    fi
    echo "=================================================="
    
    # 清理临时文件
    rm -f /tmp/luci_before.txt /tmp/luci_after.txt
}

# --- 主执行流程 ---
main() {
    echo "开始执行自定义软件源集成脚本..."
    
    # 1. 将自定义软件源添加到 feeds.conf.default 文件
    add_feeds
    
    # 检查是否有成功添加的软件源，如果没有则退出
    if [ ${#SUCCESS_FEEDS[@]} -eq 0 ]; then
        echo "⚠️ 没有成功添加任何新的软件源，脚本退出。"
        exit 0
    fi
    
    # 2. 更新并安装所有 feeds (包括官方和新增的)
    update_and_install_feeds
    
    # 3. 将新安装的软件包配置写入 .config 文件
    configure_packages "${SUCCESS_FEEDS[@]}"
    
    # 4. 生成最终的变更报告
    generate_luci_report
    
    echo "🎉 所有操作完成！"
}

# 调用主函数，开始执行脚本
main
