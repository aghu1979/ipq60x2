#!/bin/bash

# ==============================================================================
# OpenWrt 第三方软件源集成脚本
#
# 功能:
#   添加第三方软件源
#   检查并删除官方feeds中可能存在的不同名称的软件包
#   使用kenzok8/small-package作为后备仓库
#
# 使用方法:
#   在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本
#
# 作者: Mary
# 日期：2025-11-17
# 版本: 3.6 - 详细日志分析版
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 颜色定义 ---
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[0;37m'
COLOR_RESET='\033[0m'

# --- 图标定义 ---
ICON_INFO="ℹ️"
ICON_SUCCESS="✅"
ICON_WARNING="⚠️"
ICON_ERROR="❌"
ICON_PROCESSING="⏳"

# --- 日志函数 ---
log_info() {
    echo -e "${COLOR_BLUE}${ICON_INFO} [INFO] $1${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_GREEN}${ICON_SUCCESS} [SUCCESS] $1${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_YELLOW}${ICON_WARNING} [WARNING] $1${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_RED}${ICON_ERROR} [ERROR] $1${COLOR_RESET}"
}

log_processing() {
    echo -e "${COLOR_PURPLE}${ICON_PROCESSING} [PROCESSING] $1${COLOR_RESET}"
}

log_step() {
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN} $1${COLOR_RESET}"
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
}

# --- 统计变量 ---
SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0
TOTAL_COUNT=0

# --- 调试函数 ---

# 显示行的详细信息
debug_line() {
    local line_num="$1"
    local line_content="$2"
    
    echo -e "${COLOR_YELLOW}--- 第 $line_num 行详细信息 ---${COLOR_RESET}"
    echo -e "${COLOR_WHITE}原始内容: '$line_content'${COLOR_RESET}"
    
    # 显示字符的十六进制表示
    echo -e "${COLOR_CYAN}十六进制表示:${COLOR_RESET}"
    echo -n "$line_content" | hexdump -C
    echo ""
    
    # 检查行尾是否有特殊字符
    if [[ "$line_content" =~ $'\r'$ ]]; then
        echo -e "${COLOR_RED}警告: 行尾包含Windows回车符(\\r)${COLOR_RESET}"
    fi
    
    # 检查是否有不可见字符
    local clean_line=$(echo "$line_content" | tr -d '\r\n')
    if [[ "$line_content" != "$clean_line" ]]; then
        echo -e "${COLOR_RED}警告: 行包含不可见字符${COLOR_RESET}"
    fi
}

# 分析错误原因
analyze_feeds_error() {
    local error_line="$1"
    local line_content="$2"
    
    echo -e "${COLOR_RED}--- 错误分析 ---${COLOR_RESET}"
    
    # 检查是否为空行
    if [[ -z "$line_content" ]]; then
        echo -e "${COLOR_RED}错误原因: 空行${COLOR_RESET}"
        return
    fi
    
    # 检查是否为注释行
    if [[ "$line_content" =~ ^[[:space:]]*# ]]; then
        echo -e "${COLOR_GREEN}这是注释行，应该不会报错${COLOR_RESET}"
        return
    fi
    
    # 检查是否以src-开头
    if [[ ! "$line_content" =~ ^src- ]]; then
        echo -e "${COLOR_RED}错误原因: 不以'src-'开头${COLOR_RESET}"
        return
    fi
    
    # 检查格式
    if [[ "$line_content" =~ ^src-(git|svn|cvs|hg|link|bzr)[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+ ]]; then
        echo -e "${COLOR_GREEN}格式看起来正确，可能是其他问题${COLOR_RESET}"
        
        # 检查URL是否有效
        local url=$(echo "$line_content" | awk '{print $3}')
        if [[ "$url" =~ ^http ]] || [[ "$url" =~ ^git ]]; then
            echo -e "${COLOR_GREEN}URL格式正确${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}错误原因: URL格式不正确 '$url'${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_RED}错误原因: 格式不正确${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}正确格式应为: src-<type> <name> <url>[;<branch>]${COLOR_RESET}"
    fi
}

# --- 函数定义 ---

# 显示脚本信息
show_script_info() {
    log_step "OpenWrt 第三方软件源集成脚本"
    log_info "作者: Mary"
    log_info "版本: 3.6 - 详细日志分析版"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
}

# 检查环境
check_environment() {
    log_processing "检查执行环境..."
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 检查是否在源码根目录
    if [ ! -f "Makefile" ] || ! grep -q "OpenWrt" Makefile; then
        log_error "不在OpenWrt/ImmortalWrt源码根目录"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
    
    log_success "环境检查通过"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    return 0
}

# 克隆仓库
clone_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-}"
    
    log_processing "正在克隆 $repo_url 到 $target_dir"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 如果目标目录已存在，先删除
    if [ -d "$target_dir" ]; then
        log_info "目标目录已存在，删除旧目录"
        rm -rf "$target_dir"
    fi
    
    # 克隆仓库
    if [ -n "$branch" ]; then
        if git clone -b "$branch" "$repo_url" "$target_dir"; then
            log_success "克隆成功: $target_dir"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            log_error "克隆失败: $target_dir"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    else
        if git clone "$repo_url" "$target_dir"; then
            log_success "克隆成功: $target_dir"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            log_error "克隆失败: $target_dir"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    fi
}

# 检查并删除官方feeds中可能存在的不同名称的软件包
check_and_remove_conflicts() {
    log_processing "检查并删除官方feeds中可能存在的不同名称的软件包"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 定义可能冲突的软件包列表
    local conflict_packages=(
        "luci-app-adguardhome"
        "luci-app-ddns-go"
        "luci-app-netdata"
        "luci-app-netspeedtest"
        "luci-app-partexp"
        "luci-app-taskplan"
        "luci-app-lucky"
        "luci-app-easytier"
        "luci-app-momo"
        "luci-app-nikki"
        "luci-app-oaf"
        "luci-app-openclash"
        "luci-app-tailscale"
        "luci-app-vnt"
        "luci-app-openlist2"
        "luci-app-quickfile"
        "luci-app-passwall"
        "luci-app-passwall2"
    )
    
    local removed_count=0
    
    # 检查每个可能冲突的软件包
    for package in "${conflict_packages[@]}"; do
        # 查找官方feeds中的软件包
        local official_packages=$(find ./feeds -name "$package" -type d 2>/dev/null)
        
        if [ -n "$official_packages" ]; then
            log_info "发现官方feeds中的冲突软件包: $package"
            
            # 删除官方feeds中的软件包
            for pkg_path in $official_packages; do
                log_info "删除官方软件包: $pkg_path"
                if rm -rf "$pkg_path"; then
                    log_success "删除成功: $pkg_path"
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                    removed_count=$((removed_count + 1))
                else
                    log_error "删除失败: $pkg_path"
                    ERROR_COUNT=$((ERROR_COUNT + 1))
                fi
            done
        fi
    done
    
    if [ $removed_count -gt 0 ]; then
        log_success "共删除 $removed_count 个冲突软件包"
    else
        log_info "未发现冲突软件包"
    fi
    
    return 0
}

# 创建干净的feeds.conf.default文件
create_clean_feeds_config() {
    log_processing "创建干净的feeds.conf.default文件"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 备份原文件
    cp feeds.conf.default feeds.conf.default.backup
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 重新构建文件
    {
        # 添加原始的有效行（不包括可能出错的行）
        while IFS= read -r line; do
            # 跳过空行
            if [[ -z "$line" ]]; then
                continue
            fi
            
            # 保留注释行
            if [[ "$line" =~ ^[[:space:]]*# ]]; then
                printf "%s\n" "$line"
                continue
            fi
            
            # 只保留格式正确的行
            if [[ "$line" =~ ^src-(git|svn|cvs|hg|link|bzr)[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+ ]]; then
                printf "%s\n" "$line"
            else
                echo -e "${COLOR_YELLOW}跳过格式错误的行: $line${COLOR_RESET}"
            fi
        done < "feeds.conf.default"
        
        # 添加所有需要的第三方源
        echo -e "${COLOR_GREEN}添加第三方软件源...${COLOR_RESET}"
        printf "%s\n" "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main"
        printf "%s\n" "src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main"
        printf "%s\n" "src-git luci-app-passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main"
        printf "%s\n" "src-git luci-app-openclash https://github.com/vernesong/OpenClash.git"
        printf "%s\n" "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo.git;main"
        printf "%s\n" "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main"
        
    } > "$temp_file"
    
    # 替换原文件
    mv "$temp_file" "feeds.conf.default"
    
    log_success "feeds.conf.default文件创建完成"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    return 0
}

# 详细验证feeds.conf.default文件
validate_feeds_config_detailed() {
    log_processing "详细验证feeds.conf.default文件"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 检查文件是否存在
    if [ ! -f "feeds.conf.default" ]; then
        log_error "feeds.conf.default文件不存在"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
    
    # 显示文件内容
    log_info "当前feeds.conf.default文件内容:"
    cat -n feeds.conf.default
    echo ""
    
    # 检查文件语法
    local line_num=0
    local error_count=0
    local error_lines=()
    
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # 跳过空行和注释行
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # 检查格式是否正确
        if [[ ! "$line" =~ ^src-(git|svn|cvs|hg|link|bzr)[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+ ]]; then
            log_error "第 $line_num 行格式错误: $line"
            error_lines+=("$line_num:$line")
            error_count=$((error_count + 1))
            
            # 显示详细分析
            debug_line "$line_num" "$line"
            analyze_feeds_error "$line_num" "$line"
            echo ""
        fi
    done < "feeds.conf.default"
    
    if [ $error_count -eq 0 ]; then
        log_success "feeds.conf.default文件验证通过"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return 0
    else
        log_error "feeds.conf.default文件验证失败，发现 $error_count 个错误"
        
        # 尝试自动修复
        log_info "尝试自动修复错误..."
        create_clean_feeds_config
        
        # 再次验证
        log_info "修复后重新验证..."
        error_count=0
        line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            
            # 跳过空行和注释行
            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi
            
            # 检查格式是否正确
            if [[ ! "$line" =~ ^src-(git|svn|cvs|hg|link|bzr)[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+ ]]; then
                log_error "修复后第 $line_num 行仍然错误: $line"
                debug_line "$line_num" "$line"
                analyze_feeds_error "$line_num" "$line"
                error_count=$((error_count + 1))
            fi
        done < "feeds.conf.default"
        
        if [ $error_count -eq 0 ]; then
            log_success "修复成功，feeds.conf.default文件验证通过"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            log_error "修复失败，仍有 $error_count 个错误"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    fi
}

# 添加第三方软件源
add_third_party_feeds() {
    log_step "添加第三方软件源"
    
    # 京东云雅典娜led控制
    clone_repo "https://github.com/NONGFAH/luci-app-athena-led" "package/luci-app-athena-led"
    if [ -d "package/luci-app-athena-led" ]; then
        chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led
    fi
    
    # AdGuardHome
    clone_repo "https://github.com/sirpdboy/luci-app-adguardhome" "package/luci-app-adguardhome"
    
    # ddns-go by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-ddns-go" "package/luci-app-ddns-go"
    
    # luci-app-netdata by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-netdata" "package/luci-app-netdata"
    
    # luci-app-netspeedtest by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-netspeedtest" "package/luci-app-netspeedtest"
    
    # luci-app-partexp by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-partexp" "package/luci-app-partexp"
    
    # luci-app-taskplan by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-taskplan" "package/luci-app-taskplan"
    
    # lucky by gdy666
    clone_repo "https://github.com/gdy666/luci-app-lucky" "package/lucky"
    
    # luci-app-easytier
    clone_repo "https://github.com/EasyTier/luci-app-easytier" "package/luci-app-easytier"
    
    # homeproxy
    clone_repo "https://github.com/VIKINGYFY/homeproxy" "package/homeproxy"
    
    # golang & luci-app-openlist2 by sbwml
    clone_repo "https://github.com/sbwml/packages_lang_golang" "feeds/packages/lang/golang" "25.x"
    clone_repo "https://github.com/sbwml/luci-app-openlist2" "package/luci-app-openlist2"
    
    # luci-app-mosdns by sbwml
    clone_repo "https://github.com/sbwml/luci-app-mosdns" "package/luci-app-mosdns" "v5"
    
    # luci-app-quickfile by sbwml
    clone_repo "https://github.com/sbwml/luci-app-quickfile" "package/luci-app-quickfile"
    
    # OpenAppFilter（OAF）
    clone_repo "https://github.com/destan19/OpenAppFilter" "package/luci-app-oaf"
    
    # tailscale
    if [ -f "feeds/packages/net/tailscale/Makefile" ]; then
        log_info "处理tailscale特殊需求"
        sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
    fi
    clone_repo "https://github.com/asvow/luci-app-tailscale" "package/luci-app-tailscale"
    
    # vnt
    clone_repo "https://github.com/lmq8267/luci-app-vnt" "package/luci-app-vnt"
    
    # kenzok8/small-package，后备之选
    clone_repo "https://github.com/kenzok8/small-package" "small"
    
    # 创建干净的feeds.conf.default文件
    create_clean_feeds_config
    
    # 详细验证feeds.conf.default文件
    validate_feeds_config_detailed
    
    log_success "第三方软件源添加完成"
}

# 生成摘要报告
generate_final_summary() {
    log_step "生成执行摘要"
    
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN} 执行摘要${COLOR_RESET}"
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_WHITE}总操作数: ${TOTAL_COUNT}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}成功操作数: ${SUCCESS_COUNT}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}警告操作数: ${WARNING_COUNT}${COLOR_RESET}"
    echo -e "${COLOR_RED}错误操作数: ${ERROR_COUNT}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    
    if [ $ERROR_COUNT -eq 0 ]; then
        log_success "所有操作均成功完成"
        return 0
    else
        log_error "存在 $ERROR_COUNT 个错误操作"
        return 1
    fi
}

# =============================================================================
# 主执行流程
# =============================================================================

main() {
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 显示脚本信息
    show_script_info
    
    # 检查环境
    if check_environment; then
        # 检查并删除官方feeds中可能存在的不同名称的软件包
        check_and_remove_conflicts
        
        # 添加第三方软件源
        add_third_party_feeds
        
        # 生成摘要报告
        generate_final_summary
    else
        log_error "环境检查失败，终止执行"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        generate_final_summary
        exit 1
    fi
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "总执行时间: ${duration}秒"
    
    # 返回执行结果
    if [ $ERROR_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 执行主函数
main "$@"
