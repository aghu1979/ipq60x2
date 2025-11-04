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
# 作者: Mary 日期：20251104
# ==============================================================================

# --- 颜色和符号定义 ---
COLOR_RED='\033[1;91m'       # 亮红色 - 用于移除项
COLOR_GREEN='\033[1;92m'     # 亮绿色 - 用于新增项
COLOR_YELLOW='\033[1;93m'    # 亮黄色 - 用于标题和警告
COLOR_BLUE='\033[1;94m'      # 亮蓝色 - 用于信息
COLOR_CYAN='\033[1;96m'      # 亮青色 - 用于列表项
COLOR_WHITE='\033[1;97m'     # 亮白色 - 用于边框
COLOR_RESET='\033[0m'        # 重置颜色

SYMBOL_ADD="${COLOR_GREEN}✅${COLOR_RESET}"
SYMBOL_REMOVE="${COLOR_RED}❌${COLOR_RESET}"
SYMBOL_BULLET="${COLOR_CYAN}▸${COLOR_RESET}"
SYMBOL_INFO="${COLOR_BLUE}ℹ${COLOR_RESET}"
SYMBOL_REPORT="${COLOR_YELLOW}📄${COLOR_RESET}"

# --- 文件路径定义 ---
CONFIG_FILE=".config"
BEFORE_FILE=".luci_report_before.cfg"
AFTER_FILE=".luci_report_after.cfg"

# --- 检查依赖 ---
if ! command -v comm &> /dev/null; then
    echo -e "${COLOR_RED}错误: 'comm' 命令未找到，此脚本无法运行。${COLOR_RESET}"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${COLOR_RED}错误: 未找到 '$CONFIG_FILE' 文件。请确保在源码根目录下运行此脚本。${COLOR_RESET}"
    exit 1
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
get_luci_packages() {
    grep '^CONFIG_LUCI.*=y$' "$CONFIG_FILE" | sed 's/^CONFIG_\(.*\)=y$/\1/' | sort
}

# 打印软件包列表
print_list() {
    local file_path="$1"
    
    if [ -s "$file_path" ]; then
        while IFS= read -r package; do
            echo -e "  ${SYMBOL_BULLET} ${package}"
        done < "$file_path"
    else
        echo -e "  ${COLOR_BLUE}(列表为空)${COLOR_RESET}"
    fi
}

# --- 主逻辑 ---

# 第一次运行 (make defconfig 之前)
if [ ! -f "$BEFORE_FILE" ]; then
    echo -e "${SYMBOL_INFO} ${COLOR_YELLOW}首次运行：正在建立 LUCI 软件包的基准配置...${COLOR_RESET}"
    
    get_luci_packages > "$BEFORE_FILE"
    
    print_section_header "基准配置已成功捕获"
    print_list "$BEFORE_FILE"
    
    echo -e "\n${COLOR_BLUE}提示: 基准配置已保存到 '$BEFORE_FILE'。"
    echo -e "请运行 'make defconfig' 后再次执行本脚本以生成变更报告。${COLOR_RESET}"

# 第二次运行 (make defconfig 之后)
else
    echo -e "${SYMBOL_REPORT} ${COLOR_YELLOW}正在生成 LUCI 软件包变更报告...${COLOR_RESET}"
    
    get_luci_packages > "$AFTER_FILE"
    
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
    print_list "$BEFORE_FILE"
    
    # 2. 当前配置
    print_section_header "2. 当前配置 (make defconfig 后)"
    print_list "$AFTER_FILE"
    
    # 3. 变更摘要
    print_section_header "3. 变更摘要"
    
    ADDED_PACKAGES=$(comm -13 "$BEFORE_FILE" "$AFTER_FILE")
    REMOVED_PACKAGES=$(comm -23 "$BEFORE_FILE" "$AFTER_FILE")
    
    if [ -n "$ADDED_PACKAGES" ]; then
        echo -e "${COLOR_GREEN}🎉 新增的软件包 (${COLOR_CYAN}$(echo "$ADDED_PACKAGES" | wc -l)${COLOR_GREEN} 个)${COLOR_RESET}"
        while IFS= read -r package; do
            echo -e "  ${SYMBOL_ADD} ${package}"
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

echo -e "\n${COLOR_CYAN}脚本执行完毕。${COLOR_RESET}"
