# scripts/luci_report.sh
#!/bin/bash

# ==============================================================================
# LUCI 软件包变更报告生成器
#
# 功能:
#   此脚本用于生成 OpenWrt/ImmortalWrt 在执行 'make defconfig' 前后，
#   .config 文件中 LUCI 软件包的详细变更报告。
#
# 使用方法:
#   1. 在修改 feeds 或添加自定义软件包后，首次运行此脚本以建立基准配置。
#   2. 执行 'make defconfig'。
#   3. 再次运行此脚本，它将自动生成一份包含变更详情的完整报告。
#
# 注意: 请在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本。
# 作者: Mary
# 日期：20251104
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 文件路径定义
CONFIG_FILE=".config"
USER_CONFIG_FILE="configs/immu.config"  # 用户提供的配置文件
BEFORE_FILE=".luci_report_before.cfg"
AFTER_FILE=".luci_report_after.cfg"
REPORT_FILE=".luci_report.txt"
DETAIL_REPORT_FILE=".luci_detailed_report.html"

# --- 颜色和符号定义 ---
COLOR_RED='\033[1;91m'       # 亮红色 - 用于移除项
COLOR_GREEN='\033[1;92m'     # 亮绿色 - 用于新增项
COLOR_YELLOW='\033[1;93m'    # 亮黄色 - 用于标题和警告
COLOR_BLUE='\033[1;94m'      # 亮蓝色 - 用于信息
COLOR_CYAN='\033[1;96m'      # 亮青色 - 用于列表项
COLOR_WHITE='\033[1;97m'     # 亮白色 - 用于边框
COLOR_MAGENTA='\033[1;95m'   # 洋红色 - 用于本地package
COLOR_ORANGE='\033[0;33m'    # 橙色 - 用于特殊标记
COLOR_RESET='\033[0m'        # 重置颜色

SYMBOL_ADD="${COLOR_GREEN}✅${COLOR_RESET}"
SYMBOL_REMOVE="${COLOR_RED}❌${COLOR_RESET}"
SYMBOL_BULLET="${COLOR_CYAN}▸${COLOR_RESET}"
SYMBOL_INFO="${COLOR_BLUE}ℹ${COLOR_RESET}"
SYMBOL_REPORT="${COLOR_YELLOW}📄${COLOR_RESET}"
SYMBOL_WARNING="${COLOR_YELLOW}⚠️${COLOR_RESET}"
SYMBOL_STAR="${COLOR_YELLOW}⭐${COLOR_RESET}"
SYMBOL_PACKAGE="${COLOR_BLUE}📦${COLOR_RESET}"

# 记录开始时间
SCRIPT_START_TIME=$(date +%s)

log_step "开始生成 LUCI 软件包变更报告"

# 显示系统资源使用情况
show_system_resources

# --- 检查依赖 ---
check_command_exists "comm" "'comm' 命令未找到，此脚本无法运行。"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    # 如果.config不存在，尝试从用户配置文件复制
    if [ -f "$USER_CONFIG_FILE" ]; then
        log_info "未找到 .config 文件，从用户配置文件复制: $USER_CONFIG_FILE"
        cp "$USER_CONFIG_FILE" "$CONFIG_FILE"
    else
        log_error "未找到 '$CONFIG_FILE' 文件，也未找到用户配置文件 '$USER_CONFIG_FILE'。请确保在源码根目录下运行此脚本。"
        exit 1
    fi
fi

# --- 核心函数 ---

# 打印带边框的标题
print_header() {
    local title="$1"
    local title_color="$2"
    local border_char="═"
    local title_length=${#title}
    local border_length=$((title_length + 10))
    
    echo -e "${COLOR_WHITE}"
    printf '%*s\n' "$border_length" '' | tr ' ' "$border_char"
    printf "%*s%s%*s\n" $(((border_length - title_length) / 2)) '' "${title_color}${title}${COLOR_WHITE}" $(((border_length - title_length + 1) / 2)) '' | tr ' ' "$border_char"
    printf '%*s\n' "$border_length" '' | tr ' ' "$border_char"
    echo -e "${COLOR_RESET}"
}

# 打印小节标题
print_section_header() {
    echo -e "\n${COLOR_YELLOW}--- $1 ---${COLOR_RESET}\n"
}

# 获取并排序 LUCI 软件包列表
# 优先从.config获取，如果.config没有变化则强制重新生成
get_luci_packages() {
    local config_file="$1"
    local force_refresh=${2:-false}
    
    # 如果强制刷新或.config不存在，从用户配置文件获取
    if [ "$force_refresh" = "true" ] || [ ! -f "$config_file" ]; then
        if [ -f "$USER_CONFIG_FILE" ]; then
            log_debug "从用户配置文件获取LUCI软件包列表"
            grep "^CONFIG_PACKAGE_luci-app.*=y$" "$USER_CONFIG_FILE" | \
            grep -v "_INCLUDE_" | \
            sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | \
            sort
        fi
    else
        log_debug "从.config文件获取LUCI软件包列表"
        grep "^CONFIG_PACKAGE_luci-app.*=y$" "$config_file" | \
        grep -v "_INCLUDE_" | \
        sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | \
        sort
    fi
}

# 分析包的来源
analyze_package_source() {
    local package_name="$1"
    
    # 检查是否在本地 package 目录中
    if [ -d "package/$package_name" ]; then
        echo "local"
        return 0
    fi
    
    # 检查是否在 feeds/luci/applications 目录中
    if [ -d "feeds/luci/applications/$package_name" ]; then
        echo "feeds/luci"
        return 0
    fi
    
    # 检查是否在 feeds/packages 目录中（递归查找）
    local found_in_feeds=$(find feeds/packages -name "$package_name" -type d 2>/dev/null | head -1)
    if [ -n "$found_in_feeds" ]; then
        echo "feeds/packages"
        return 0
    fi
    
    # 检查是否在 package/feeds 目录中（安装后的feeds）
    if [ -d "package/feeds" ]; then
        local found_in_package_feeds=$(find package/feeds -name "$package_name" -type d 2>/dev/null | head -1)
        if [ -n "$found_in_package_feeds" ]; then
            echo "package/feeds"
            return 0
        fi
    fi
    
    # 检查是否在 small-package 目录中
    if [ -d "small/$package_name" ]; then
        echo "small-package"
        return 0
    fi
    
    echo "unknown"
    return 1
}

# 获取包的描述信息
get_package_description() {
    local package_name="$1"
    local makefile=""
    
    # 查找Makefile
    if [ -f "package/$package_name/Makefile" ]; then
        makefile="package/$package_name/Makefile"
    elif [ -f "feeds/luci/applications/$package_name/Makefile" ]; then
        makefile="feeds/luci/applications/$package_name/Makefile"
    elif [ -d "feeds/packages" ]; then
        makefile=$(find feeds/packages -name "$package_name" -type d 2>/dev/null | head -1)/Makefile
    fi
    
    if [ -f "$makefile" ]; then
        grep "^PKG_TITLE:=" "$makefile" 2>/dev/null | sed 's/^PKG_TITLE:=//' | sed 's/^"//;s/"$//'
    fi
}

# 打印软件包列表（带来源分析和描述）
print_list_with_source() {
    local file_path="$1"
    local title="$2"
    
    if [ -s "$file_path" ]; then
        echo -e "\n${COLOR_BLUE}${SYMBOL_PACKAGE} $title (${COLOR_CYAN}$(cat "$file_path" | wc -l)${COLOR_BLUE} 个软件包)${COLOR_RESET}\n"
        
        while IFS= read -r package; do
            source=$(analyze_package_source "$package")
            description=$(get_package_description "$package")
            
            # 根据来源选择图标和颜色
            case "$source" in
                "local")
                    icon="🔧"
                    color="${COLOR_MAGENTA}"
                    source_text="[本地package]"
                    ;;
                "feeds/luci")
                    icon="🌐"
                    color="${COLOR_GREEN}"
                    source_text="[官方luci]"
                    ;;
                "feeds/packages")
                    icon="📦"
                    color="${COLOR_CYAN}"
                    source_text="[官方packages]"
                    ;;
                "package/feeds")
                    icon="📥"
                    color="${COLOR_BLUE}"
                    source_text="[已安装feeds]"
                    ;;
                "small-package")
                    icon="🔄"
                    color="${COLOR_YELLOW}"
                    source_text="[后备仓库]"
                    ;;
                *)
                    icon="❓"
                    color="${COLOR_RED}"
                    source_text="[未知来源]"
                    ;;
            esac
            
            # 显示包名、来源和描述
            echo -e "  ${icon} ${color}${package}${COLOR_RESET} ${source_text}"
            if [ -n "$description" ]; then
                echo -e "     ${COLOR_ORANGE}▸${COLOR_RESET} ${description}"
            fi
            echo ""
        done < "$file_path"
    else
        echo -e "\n${COLOR_BLUE}${SYMBOL_PACKAGE} $title${COLOR_RESET}"
        echo -e "  ${COLOR_BLUE}(列表为空)${COLOR_RESET}\n"
    fi
}

# 分析变更原因
analyze_change_reason() {
    local package="$1"
    local change_type="$2"  # "added" or "removed"
    
    case "$change_type" in
        "added")
            # 检查是否是新添加的第三方源
            if [ -d "package/$package" ]; then
                echo "通过repo.sh添加的第三方软件包"
            elif [ -d "small/$package" ]; then
                echo "来自small-package后备仓库"
            elif [ -d "package/feeds" ]; then
                echo "通过feeds安装的软件包"
            else
                echo "可能是依赖项自动安装"
            fi
            ;;
        "removed")
            echo "可能是不满足依赖条件或被手动禁用"
            ;;
    esac
}

# 生成HTML详细报告
generate_html_report() {
    local before_file="$1"
    local after_file="$2"
    local report_file="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    ADDED_PACKAGES=$(comm -13 "$before_file" "$after_file")
    REMOVED_PACKAGES=$(comm -23 "$before_file" "$after_file")
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LUCI 软件包变更报告 - $timestamp</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 8px 8px 0 0; }
        .section { padding: 20px; border-bottom: 1px solid #eee; }
        .section:last-child { border-bottom: none; }
        h1 { margin: 0; font-size: 28px; }
        h2 { color: #333; margin-top: 0; }
        .package-list { list-style: none; padding: 0; }
        .package-item { padding: 15px; margin: 10px 0; border-radius: 6px; transition: transform 0.2s; }
        .package-item:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        .added { background-color: #d4edda; border-left: 4px solid #28a745; }
        .removed { background-color: #f8d7da; border-left: 4px solid #dc3545; }
        .package-name { font-weight: bold; font-size: 18px; }
        .package-source { color: #666; font-size: 14px; margin-top: 5px; }
        .package-desc { color: #555; margin-top: 8px; line-height: 1.5; }
        .package-reason { color: #888; font-style: italic; margin-top: 8px; font-size: 13px; }
        .stats { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat-item { text-align: center; padding: 20px; background: #f8f9fa; border-radius: 6px; }
        .stat-number { font-size: 36px; font-weight: bold; color: #333; }
        .stat-label { color: #666; margin-top: 5px; }
        .icon { margin-right: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 LUCI 软件包变更报告</h1>
            <p>生成时间: $timestamp</p>
        </div>
        
        <div class="section">
            <div class="stats">
                <div class="stat-item">
                    <div class="stat-number" style="color: #28a745;">$(echo "$ADDED_PACKAGES" | grep -c .)</div>
                    <div class="stat-label">新增软件包</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number" style="color: #dc3545;">$(echo "$REMOVED_PACKAGES" | grep -c .)</div>
                    <div class="stat-label">移除软件包</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number" style="color: #007bff;">$(cat "$after_file" | wc -l)</div>
                    <div class="stat-label">总计软件包</div>
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>✅ 新增的软件包</h2>
            <div class="package-list">
EOF

    # 添加新增的软件包
    if [ -n "$ADDED_PACKAGES" ]; then
        while IFS= read -r package; do
            source=$(analyze_package_source "$package")
            description=$(get_package_description "$package")
            reason=$(analyze_change_reason "$package" "added")
            
            # 根据来源选择图标
            case "$source" in
                "local") icon="🔧" ;;
                "feeds/luci") icon="🌐" ;;
                "feeds/packages") icon="📦" ;;
                "package/feeds") icon="📥" ;;
                "small-package") icon="🔄" ;;
                *) icon="❓" ;;
            esac
            
            cat >> "$report_file" << EOF
                <div class="package-item added">
                    <div class="package-name">${icon} ${package}</div>
                    <div class="package-source">来源: ${source}</div>
                    <div class="package-desc">${description:-"无描述信息"}</div>
                    <div class="package-reason">原因: ${reason}</div>
                </div>
EOF
        done <<< "$ADDED_PACKAGES"
    else
        echo "                <p>没有新增的软件包。</p>" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
            </div>
        </div>
        
        <div class="section">
            <h2>❌ 移除的软件包</h2>
            <div class="package-list">
EOF

    # 添加移除的软件包
    if [ -n "$REMOVED_PACKAGES" ]; then
        while IFS= read -r package; do
            reason=$(analyze_change_reason "$package" "removed")
            
            cat >> "$report_file" << EOF
                <div class="package-item removed">
                    <div class="package-name">❌ ${package}</div>
                    <div class="package-reason">原因: ${reason}</div>
                </div>
EOF
        done <<< "$REMOVED_PACKAGES"
    else
        echo "                <p>没有移除的软件包。</p>" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
            </div>
        </div>
    </div>
</body>
</html>
EOF

    log_info "HTML详细报告已保存到: $report_file"
}

# 生成文本报告文件
generate_report_file() {
    local before_file="$1"
    local after_file="$2"
    local report_file="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    ADDED_PACKAGES=$(comm -13 "$before_file" "$after_file")
    REMOVED_PACKAGES=$(comm -23 "$before_file" "$after_file")
    
    {
        echo "LUCI 软件包变更报告 - $timestamp"
        echo "=================================="
        echo ""
        echo "📊 统计摘要:"
        echo "  新增软件包: $(echo "$ADDED_PACKAGES" | grep -c .) 个"
        echo "  移除软件包: $(echo "$REMOVED_PACKAGES" | grep -c .) 个"
        echo "  总计软件包: $(cat "$after_file" | wc -l) 个"
        echo ""
        echo "✅ 新增的软件包:"
        if [ -n "$ADDED_PACKAGES" ]; then
            while IFS= read -r package; do
                source=$(analyze_package_source "$package")
                reason=$(analyze_change_reason "$package" "added")
                echo "  - $package [$source] - $reason"
            done <<< "$ADDED_PACKAGES"
        else
            echo "  无"
        fi
        echo ""
        echo "❌ 移除的软件包:"
        if [ -n "$REMOVED_PACKAGES" ]; then
            while IFS= read -r package; do
                reason=$(analyze_change_reason "$package" "removed")
                echo "  - $package - $reason"
            done <<< "$REMOVED_PACKAGES"
        else
            echo "  无"
        fi
    } > "$report_file"
    
    log_info "文本报告已保存到: $report_file"
}

# --- 主逻辑 ---

# 第一次运行 (make defconfig 之前)
if [ ! -f "$BEFORE_FILE" ]; then
    log_substep "首次运行：建立 LUCI 软件包的基准配置"
    
    # 显示使用的配置文件
    if [ -f "$USER_CONFIG_FILE" ]; then
        log_info "使用用户配置文件: $USER_CONFIG_FILE"
    else
        log_info "使用默认配置文件: $CONFIG_FILE"
    fi
    
    # 强制从用户配置文件获取基准配置
    get_luci_packages "$CONFIG_FILE" true > "$BEFORE_FILE"
    check_status "获取 LUCI 软件包列表失败"
    
    print_section_header "基准配置已成功捕获"
    print_list_with_source "$BEFORE_FILE" "基准配置中的LUCI软件包"
    
    # 添加来源说明
    echo -e "\n${COLOR_BLUE}来源说明：${NC}"
    echo -e "  ${COLOR_MAGENTA}🔧 [本地package]${NC} - 手动添加到 package 目录的包"
    echo -e "  ${COLOR_GREEN}🌐 [官方luci]${NC} - 来自官方 luci feeds 的包"
    echo -e "  ${COLOR_CYAN}📦 [官方packages]${NC} - 来自官方 packages feeds 的包"
    echo -e "  ${COLOR_BLUE}📥 [已安装feeds]${NC} - 已安装的 feeds 包（位于 package/feeds）"
    echo -e "  ${COLOR_YELLOW}🔄 [后备仓库]${NC} - 来自 small-package 后备仓库的包"
    echo -e "  ${COLOR_RED}❓ [未知来源]${NC} - 无法确定来源的包"
    
    echo -e "\n${COLOR_BLUE}提示: 基准配置已保存到 '$BEFORE_FILE'。"
    echo -e "请运行 'make defconfig' 后再次执行本脚本以生成变更报告。${COLOR_RESET}"

# 第二次运行 (make defconfig 之后)
else
    log_substep "生成 LUCI 软件包变更报告"
    
    # 强制从当前.config获取最新配置
    get_luci_packages "$CONFIG_FILE" true > "$AFTER_FILE"
    check_status "获取当前 LUCI 软件包列表失败"
    
    # 检查配置是否真的发生了变化
    if cmp -s "$BEFORE_FILE" "$AFTER_FILE"; then
        echo -e "\n${COLOR_YELLOW}${SYMBOL_WARNING} 检测到配置文件未发生变化。${COLOR_RESET}"
        echo -e "${COLOR_BLUE}可能的原因：${NC}"
        echo -e "  1. ${COLOR_CYAN}make defconfig${COLOR_RESET} 未执行或执行后配置无变化"
        echo -e "  2. ${COLOR_CYAN}feeds${COLOR_RESET} 更新后软件包列表无变化"
        echo -e "  3. ${COLOR_CYAN}第三方源${COLOR_RESET} 添加的软件包未生效"
        echo ""
        echo -e "${COLOR_BLUE}建议操作：${NC}"
        echo -e "  1. 检查 ${COLOR_CYAN}feeds${COLOR_RESET} 是否正确更新和安装"
        echo -e "  2. 检查 ${COLOR_CYAN}repo.sh${COLOR_RESET} 是否正确执行"
        echo -e "  3. 尝试重新运行 ${COLOR_CYAN}make defconfig${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}是否强制重新生成报告？(y/n)${COLOR_RESET}"
        read -r -p "> " choice
        case "$choice" in
          y|Y )
            echo -e "${COLOR_BLUE}强制重新生成报告...${COLOR_RESET}"
            rm -f "$AFTER_FILE"
            get_luci_packages "$CONFIG_FILE" true > "$AFTER_FILE"
            ;;
          * )
            rm -f "$AFTER_FILE" # 清理无用的 after 文件
            exit 0
            ;;
        esac
    fi

    # 生成报告
    REPORT_TITLE="LUCI 软件包变更报告"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    clear # 清屏以获得更好的报告显示效果
    
    print_header "${REPORT_TITLE} - ${TIMESTAMP}" "$COLOR_YELLOW"
    
    # 1. 基准配置
    print_list_with_source "$BEFORE_FILE" "📋 基准配置 (make defconfig 前)"
    
    # 2. 当前配置
    print_list_with_source "$AFTER_FILE" "📋 当前配置 (make defconfig 后)"
    
    # 3. 变更摘要
    print_section_header "📊 变更摘要"
    
    ADDED_PACKAGES=$(comm -13 "$BEFORE_FILE" "$AFTER_FILE")
    REMOVED_PACKAGES=$(comm -23 "$BEFORE_FILE" "$AFTER_FILE")
    
    # 显示统计信息
    echo -e "${COLOR_BLUE}📈 统计信息:${NC}"
    echo -e "  ${SYMBOL_ADD} 新增: ${COLOR_GREEN}$(echo "$ADDED_PACKAGES" | grep -c .)${COLOR_RESET} 个"
    echo -e "  ${SYMBOL_REMOVE} 移除: ${COLOR_RED}$(echo "$REMOVED_PACKAGES" | grep -c .)${COLOR_RESET} 个"
    echo -e "  ${SYMBOL_PACKAGE} 总计: ${COLOR_CYAN}$(cat "$AFTER_FILE" | wc -l)${COLOR_RESET} 个"
    echo ""
    
    if [ -n "$ADDED_PACKAGES" ]; then
        echo -e "${COLOR_GREEN}${SYMBOL_STAR} 新增的软件包 (${COLOR_CYAN}$(echo "$ADDED_PACKAGES" | grep -c .)${COLOR_GREEN} 个)${COLOR_RESET}\n"
        while IFS= read -r package; do
            source=$(analyze_package_source "$package")
            description=$(get_package_description "$package")
            reason=$(analyze_change_reason "$package" "added")
            
            # 根据来源选择图标和颜色
            case "$source" in
                "local")
                    icon="🔧"
                    color="${COLOR_MAGENTA}"
                    source_text="[本地package]"
                    ;;
                "feeds/luci")
                    icon="🌐"
                    color="${COLOR_GREEN}"
                    source_text="[官方luci]"
                    ;;
                "feeds/packages")
                    icon="📦"
                    color="${COLOR_CYAN}"
                    source_text="[官方packages]"
                    ;;
                "package/feeds")
                    icon="📥"
                    color="${COLOR_BLUE}"
                    source_text="[已安装feeds]"
                    ;;
                "small-package")
                    icon="🔄"
                    color="${COLOR_YELLOW}"
                    source_text="[后备仓库]"
                    ;;
                *)
                    icon="❓"
                    color="${COLOR_RED}"
                    source_text="[未知来源]"
                    ;;
            esac
            
            echo -e "  ${icon} ${color}${package}${COLOR_RESET} ${source_text}"
            if [ -n "$description" ]; then
                echo -e "     ${COLOR_ORANGE}▸${COLOR_RESET} ${description}"
            fi
            echo -e "     ${COLOR_BLUE}原因:${COLOR_RESET} ${reason}"
            echo ""
        done <<< "$ADDED_PACKAGES"
    else
        echo -e "${COLOR_BLUE}${SYMBOL_PACKAGE} 没有新增的软件包。${COLOR_RESET}\n"
    fi
    
    if [ -n "$REMOVED_PACKAGES" ]; then
        echo -e "${COLOR_RED}${SYMBOL_STAR} 移除的软件包 (${COLOR_CYAN}$(echo "$REMOVED_PACKAGES" | grep -c .)${COLOR_RED} 个)${COLOR_RESET}\n"
        while IFS= read -r package; do
            reason=$(analyze_change_reason "$package" "removed")
            echo -e "  ${SYMBOL_REMOVE} ${COLOR_RED}${package}${COLOR_RESET}"
            echo -e "     ${COLOR_BLUE}原因:${COLOR_RESET} ${reason}"
            echo ""
        done <<< "$REMOVED_PACKAGES"
    else
        echo -e "${COLOR_BLUE}${SYMBOL_PACKAGE} 没有移除的软件包。${COLOR_RESET}\n"
    fi
    
    echo -e "${COLOR_WHITE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    
    # 生成报告文件
    generate_report_file "$BEFORE_FILE" "$AFTER_FILE" "$REPORT_FILE"
    generate_html_report "$BEFORE_FILE" "$AFTER_FILE" "$DETAIL_REPORT_FILE"
    
    # 清理临时文件
    echo -e "\n${COLOR_BLUE}报告生成完毕。${NC}"
    echo -e "  📄 文本报告: ${COLOR_CYAN}$REPORT_FILE${NC}"
    echo -e "  🌐 HTML报告: ${COLOR_CYAN}$DETAIL_REPORT_FILE${NC}"
    echo ""
    echo -e "${COLOR_BLUE}是否删除临时文件以便下次使用? (y/n)${COLOR_RESET}"
    read -r -p "> " choice
    case "$choice" in
      y|Y )
        rm -f "$BEFORE_FILE" "$AFTER_FILE"
        echo -e "${COLOR_GREEN}✅ 临时文件已删除，已准备好进行下一次对比。${COLOR_RESET}"
        ;;
      * )
        echo -e "${COLOR_YELLOW}⚠️  临时文件已保留。如需重新开始，请手动删除 '$BEFORE_FILE'。${COLOR_RESET}"
        ;;
    esac
fi

# 显示当前磁盘使用情况
log_info "当前磁盘使用情况:"
df -h

# 记录结束时间并生成摘要
SCRIPT_END_TIME=$(date +%s)
generate_summary "LUCI 软件包变更报告生成" "$SCRIPT_START_TIME" "$SCRIPT_END_TIME" "成功"

echo -e "\n${COLOR_CYAN}脚本执行完毕。${COLOR_RESET}"
