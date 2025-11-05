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
BEFORE_FILE=".luci_report_before.cfg"
AFTER_FILE=".luci_report_after.cfg"
REPORT_FILE=".luci_report.txt"

# --- 颜色和符号定义 ---
COLOR_RED='\033[1;91m'       # 亮红色 - 用于移除项
COLOR_GREEN='\033[1;92m'     # 亮绿色 - 用于新增项
COLOR_YELLOW='\033[1;93m'    # 亮黄色 - 用于标题和警告
COLOR_BLUE='\033[1;94m'      # 亮蓝色 - 用于信息
COLOR_CYAN='\033[1;96m'      # 亮青色 - 用于列表项
COLOR_WHITE='\033[1;97m'     # 亮白色 - 用于边框
COLOR_MAGENTA='\033[1;95m'   # 洋红色 - 用于本地package
COLOR_RESET='\033[0m'        # 重置颜色

SYMBOL_ADD="${COLOR_GREEN}✅${COLOR_RESET}"
SYMBOL_REMOVE="${COLOR_RED}❌${COLOR_RESET}"
SYMBOL_BULLET="${COLOR_CYAN}▸${COLOR_RESET}"
SYMBOL_INFO="${COLOR_BLUE}ℹ${COLOR_RESET}"
SYMBOL_REPORT="${COLOR_YELLOW}📄${COLOR_RESET}"

# 记录开始时间
SCRIPT_START_TIME=$(date +%s)

# --- 检查依赖 ---
if ! command -v comm &> /dev/null; then
    log_error "'comm' 命令未找到，此脚本无法运行。"
    exit 1
fi

check_file_exists "$CONFIG_FILE" "未找到 '$CONFIG_FILE' 文件。请确保在源码根目录下运行此脚本。"

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
get_luci_packages() {
    # 只提取非注释行、以=y结尾的LUCI应用包，排除_INCLUDE_选项和注释掉的包
    grep "^CONFIG_PACKAGE_luci-app.*=y$" "$CONFIG_FILE" | sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | sort
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

# 打印软件包列表（带来源分析）
print_list_with_source() {
    local file_path="$1"
    
    if [ -s "$file_path" ]; then
        while IFS= read -r package; do
            source=$(analyze_package_source "$package")
            case "$source" in
                "local")
                    echo -e "  ${SYMBOL_BULLET} ${package} ${COLOR_MAGENTA}[本地package]${COLOR_RESET}"
                    ;;
                "feeds/luci")
                    echo -e "  ${SYMBOL_BULLET} ${package} ${COLOR_GREEN}[feeds/luci]${COLOR_RESET}"
                    ;;
                "feeds/packages")
                    echo -e "  ${SYMBOL_BULLET} ${package} ${COLOR_CYAN}[feeds/packages]${COLOR_RESET}"
                    ;;
                "package/feeds")
                    echo -e "  ${SYMBOL_BULLET} ${package} ${COLOR_BLUE}[package/feeds]${COLOR_RESET}"
                    ;;
                "small-package")
                    echo -e "  ${SYMBOL_BULLET} ${package} ${COLOR_YELLOW}[small-package]${COLOR_RESET}"
                    ;;
                *)
                    echo -e "  ${SYMBOL_BULLET} ${package} ${COLOR_RED}[未知来源]${COLOR_RESET}"
                    ;;
            esac
        done < "$file_path"
    else
        echo -e "  ${COLOR_BLUE}(列表为空)${COLOR_RESET}"
    fi
}

# 生成报告文件
generate_report_file() {
    local before_file="$1"
    local after_file="$2"
    local report_file="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    {
        echo "LUCI 软件包变更报告 - $timestamp"
        echo "=================================="
        echo ""
        echo "1. 基准配置 (make defconfig 前)"
        echo "-------------------------------"
        if [ -s "$before_file" ]; then
            cat "$before_file"
        else
            echo "(列表为空)"
        fi
        echo ""
        echo "2. 当前配置 (make defconfig 后)"
        echo "-------------------------------"
        if [ -s "$after_file" ]; then
            cat "$after_file"
        else
            echo "(列表为空)"
        fi
        echo ""
        echo "3. 变更摘要"
        echo "----------"
        
        ADDED_PACKAGES=$(comm -13 "$before_file" "$after_file")
        REMOVED_PACKAGES=$(comm -23 "$before_file" "$after_file")
        
        if [ -n "$ADDED_PACKAGES" ]; then
            echo "新增的软件包 ($(echo "$ADDED_PACKAGES" | wc -l) 个)"
            echo "$ADDED_PACKAGES"
        else
            echo "没有新增的软件包。"
        fi
        
        echo ""
        
        if [ -n "$REMOVED_PACKAGES" ]; then
            echo "移除的软件包 ($(echo "$REMOVED_PACKAGES" | wc -l) 个)"
            echo "$REMOVED_PACKAGES"
        else
            echo "没有移除的软件包。"
        fi
    } > "$report_file"
    
    log_info "报告已保存到: $report_file"
}

# --- 主逻辑 ---

# 第一次运行 (make defconfig 之前)
if [ ! -f "$BEFORE_FILE" ]; then
    log_step "首次运行：建立 LUCI 软件包的基准配置"
    
    get_luci_packages > "$BEFORE_FILE"
    check_status "获取 LUCI 软件包列表失败"
    
    print_section_header "基准配置已成功捕获"
    print_list_with_source "$BEFORE_FILE"
    
    # 添加来源说明
    echo -e "\n${COLOR_BLUE}来源说明：${NC}"
    echo -e "  ${COLOR_MAGENTA}[本地package]${NC} - 手动添加到 package 目录的包"
    echo -e "  ${COLOR_GREEN}[feeds/luci]${NC} - 来自官方 luci feeds 的包"
    echo -e "  ${COLOR_CYAN}[feeds/packages]${NC} - 来自官方 packages feeds 的包"
    echo -e "  ${COLOR_BLUE}[package/feeds]${NC} - 已安装的 feeds 包（位于 package/feeds）"
    echo -e "  ${COLOR_YELLOW}[small-package]${NC} - 来自 small-package 后备仓库的包"
    echo -e "  ${COLOR_RED}[未知来源]${NC} - 无法确定来源的包"
    
    echo -e "\n${COLOR_BLUE}提示: 基准配置已保存到 '$BEFORE_FILE'。"
    echo -e "请运行 'make defconfig' 后再次执行本脚本以生成变更报告。${COLOR_RESET}"

# 第二次运行 (make defconfig 之后)
else
    log_step "生成 LUCI 软件包变更报告"
    
    get_luci_packages > "$AFTER_FILE"
    check_status "获取当前 LUCI 软件包列表失败"
    
    # 检查配置是否真的发生了变化
    if cmp -s "$BEFORE_FILE" "$AFTER_FILE"; then
        echo -e "\n${COLOR_YELLOW}检测到配置文件未发生变化。${COLOR_RESET}"
        echo -e "${COLOR_BLUE}请确保您已运行 'make defconfig' 或修改了影响 LUCI 包的配置。${COLOR_RESET}"
        rm -f "$AFTER_FILE" # 清理无用的 after 文件
        exit 0
    fi

    # 生成报告
    REPORT_TITLE="LUCI 软件包变更报告"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    clear # 清屏以获得更好的报告显示效果
    
    print_header "${REPORT_TITLE} - ${TIMESTAMP}" "$COLOR_YELLOW"
    
    # 1. 基准配置
    print_section_header "1. 基准配置 (make defconfig 前)"
    print_list_with_source "$BEFORE_FILE"
    
    # 2. 当前配置
    print_section_header "2. 当前配置 (make defconfig 后)"
    print_list_with_source "$AFTER_FILE"
    
    # 3. 变更摘要
    print_section_header "3. 变更摘要"
    
    ADDED_PACKAGES=$(comm -13 "$BEFORE_FILE" "$AFTER_FILE")
    REMOVED_PACKAGES=$(comm -23 "$BEFORE_FILE" "$AFTER_FILE")
    
    if [ -n "$ADDED_PACKAGES" ]; then
        echo -e "${COLOR_GREEN}🎉 新增的软件包 (${COLOR_CYAN}$(echo "$ADDED_PACKAGES" | wc -l)${COLOR_GREEN} 个)${COLOR_RESET}"
        while IFS= read -r package; do
            source=$(analyze_package_source "$package")
            case "$source" in
                "local")
                    echo -e "  ${SYMBOL_ADD} ${package} ${COLOR_MAGENTA}[本地package]${COLOR_RESET}"
                    ;;
                "feeds/luci")
                    echo -e "  ${SYMBOL_ADD} ${package} ${COLOR_GREEN}[feeds/luci]${COLOR_RESET}"
                    ;;
                "feeds/packages")
                    echo -e "  ${SYMBOL_ADD} ${package} ${COLOR_CYAN}[feeds/packages]${COLOR_RESET}"
                    ;;
                "package/feeds")
                    echo -e "  ${SYMBOL_ADD} ${package} ${COLOR_BLUE}[package/feeds]${COLOR_RESET}"
                    ;;
                "small-package")
                    echo -e "  ${SYMBOL_ADD} ${package} ${COLOR_YELLOW}[small-package]${COLOR_RESET}"
                    ;;
                *)
                    echo -e "  ${SYMBOL_ADD} ${package} ${COLOR_RED}[未知来源]${COLOR_RESET}"
                    ;;
            esac
        done <<< "$ADDED_PACKAGES"
    else
        echo -e "${COLOR_BLUE}🎉 没有新增的软件包。${COLOR_RESET}"
    fi
    
    echo # 分隔线
    
    if [ -n "$REMOVED_PACKAGES" ]; then
        echo -e "${COLOR_RED}🗑️  移除的软件包 (${COLOR_CYAN}$(echo "$REMOVED_PACKAGES" | wc -l)${COLOR_RED} 个)${COLOR_RESET}"
        while IFS= read -r package; do
            echo -e "  ${SYMBOL_REMOVE} ${package}"
        done <<< "$REMOVED_PACKAGES"
    else
        echo -e "${COLOR_BLUE}🗑️  没有移除的软件包。${COLOR_RESET}"
    fi
    
    echo -e "\n${COLOR_WHITE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    
    # 生成报告文件
    generate_report_file "$BEFORE_FILE" "$AFTER_FILE" "$REPORT_FILE"
    
    # 清理临时文件
    echo -e "\n${COLOR_BLUE}报告生成完毕。是否删除临时文件以便下次使用? (y/n)${COLOR_RESET}"
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

# 记录结束时间并生成摘要
SCRIPT_END_TIME=$(date +%s)
generate_summary "LUCI 软件包变更报告生成" "$SCRIPT_START_TIME" "$SCRIPT_END_TIME" "成功"

echo -e "\n${COLOR_CYAN}脚本执行完毕。${COLOR_RESET}"
