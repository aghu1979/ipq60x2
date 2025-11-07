#!/bin/bash

# ==============================================================================
# OpenWrt 第三方软件源集成脚本
#
# 功能:
#   添加和管理 OpenWrt/ImmortalWrt 的第三方软件源
#   预先检查并删除官方feeds中可能存在的同名软件包
#   使用 small-package 作为后备仓库
#
# 使用方法:
#   在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本
#
# 作者: Mary
# 日期：20251107
# 版本: 2.1 - 网络检查优化版
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 软件源列表
declare -A REPOS=(
    ["luci-app-lucky"]="https://github.com/gdy666/luci-app-lucky.git"
    ["luci-app-easytier"]="https://github.com/EasyTier/luci-app-easytier.git"
    ["luci-app-homeproxy"]="https://github.com/VIKINGYFY/homeproxy"
    ["packages_lang_golang"]="https://github.com/sbwml/packages_lang_golang -b 25.x"
    ["luci-app-openlist2"]="https://github.com/sbwml/luci-app-openlist2"
    ["luci-app-mosdns"]="https://github.com/sbwml/luci-app-mosdns -b v5"
    ["luci-app-quickfile"]="https://github.com/sbwml/luci-app-quickfile"
    ["luci-app-momo"]="https://github.com/nikkinikki-org/OpenWrt-momo"
    ["luci-app-nikki"]="https://github.com/nikkinikki-org/OpenWrt-nikki"
    ["luci-app-oaf"]="https://github.com/destan19/OpenAppFilter.git"
    ["luci-app-openclash"]="https://github.com/vernesong/OpenClash.git -b dev"
    ["luci-app-tailscale"]="https://github.com/asvow/luci-app-tailscale"
    ["luci-app-vnt"]="https://github.com/lmq8267/luci-app-vnt.git"
    ["small-package"]="https://github.com/kenzok8/small-package"
)

# 特殊处理列表
declare -A SPECIAL_HANDLING=(
    ["packages_lang_golang"]="feeds/packages/lang/golang"
    ["luci-app-tailscale"]="pre_remove_feeds"
    ["small-package"]="small"
)

# --- 主函数 ---

# 显示脚本信息
show_script_info() {
    log_step "OpenWrt 第三方软件源集成脚本"
    log_info "作者: Mary"
    log_info "版本: 2.1 - 网络检查优化版"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 检查环境
check_environment() {
    log_info "检查执行环境..."
    
    # 检查必要命令
    local required_commands=("git" "grep" "sed" "find")
    for cmd in "${required_commands[@]}"; do
        check_command_exists "$cmd" || exit 1
    done
    
    # 检查网络连接（可跳过）
    if [ "${SKIP_NETWORK_CHECK:-0}" != "1" ]; then
        check_network || {
            log_error "网络连接异常，无法继续执行"
            log_info "提示: 可以设置 SKIP_NETWORK_CHECK=1 跳过网络检查"
            exit 1
        }
    else
        log_warn "跳过网络检查（SKIP_NETWORK_CHECK=1）"
    fi
    
    log_success "环境检查通过"
}

# 克隆或更新仓库
clone_or_update_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local target_dir="$3"
    local branch="${4:-master}"
    
    log_work "处理仓库: $repo_name"
    
    # 检查是否需要特殊处理
    local special_handling="${SPECIAL_HANDLING[$repo_name]}"
    
    # 如果目标目录已存在，先删除
    if [ -d "$target_dir" ]; then
        log_debug "删除已存在的目录: $target_dir"
        safe_remove "$target_dir" true
    fi
    
    # 克隆仓库
    if git_clone "$repo_url" "$target_dir" "$branch"; then
        log_success "仓库处理成功: $repo_name"
        return 0
    else
        log_error "仓库处理失败: $repo_name"
        return 1
    fi
}

# 预处理 tailscale
preprocess_tailscale() {
    log_info "预处理 tailscale..."
    
    # 修改 feeds/packages/net/tailscale/Makefile
    local makefile="feeds/packages/net/tailscale/Makefile"
    if [ -f "$makefile" ]; then
        log_debug "修改 tailscale Makefile"
        sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' "$makefile"
        log_success "tailscale Makefile 修改完成"
    else
        log_warn "tailscale Makefile 不存在，跳过修改"
    fi
}

# 处理特殊仓库
handle_special_repo() {
    local repo_name="$1"
    local special_handling="${SPECIAL_HANDLING[$repo_name]}"
    
    case "$special_handling" in
        "pre_remove_feeds")
            # 预处理，删除 feeds 中的相关文件
            if [ "$repo_name" = "luci-app-tailscale" ]; then
                preprocess_tailscale
            fi
            ;;
        "small")
            # small-package 特殊处理，直接克隆到 small 目录
            return 0
            ;;
        *)
            # 其他特殊处理，目标目录为 special_handling 指定的值
            return 0
            ;;
    esac
}

# 处理所有仓库
process_repos() {
    log_step "处理第三方软件源"
    
    for repo_name in "${!REPOS[@]}"; do
        local repo_url="${REPOS[$repo_name]}"
        local target_dir="package/$repo_name"
        local branch="master"
        
        # 解析仓库URL和分支
        if [[ "$repo_url" =~ -b[[:space:]]+([^[:space:]]+) ]]; then
            branch="${BASH_REMATCH[1]}"
            repo_url="${repo_url%%-b*}"
        fi
        
        # 检查是否需要特殊处理
        local special_handling="${SPECIAL_HANDLING[$repo_name]}"
        if [ -n "$special_handling" ]; then
            handle_special_repo "$repo_name"
            
            # 如果 special_handling 是目录路径，则使用它作为目标目录
            if [[ "$special_handling" == */* ]]; then
                target_dir="$special_handling"
            elif [ "$special_handling" = "small" ]; then
                target_dir="small"
            fi
        fi
        
        # 检查并删除冲突的软件包
        check_and_remove_conflicting_packages "$repo_name" "$target_dir"
        
        # 克隆或更新仓库
        clone_or_update_repo "$repo_name" "$repo_url" "$target_dir" "$branch"
    done
}

# 生成摘要报告
generate_final_summary() {
    log_step "生成执行摘要"
    
    echo ""
    echo "=================================================================="
    log_info "📊 执行摘要"
    echo "=================================================================="
    echo "✅ 成功操作: $SUCCESS_COUNT"
    echo "❌ 失败操作: $ERROR_COUNT"
    echo "⚠️  警告操作: $WARN_COUNT"
    echo ""
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "失败的操作列表:"
        for operation in "${FAILED_OPERATIONS[@]}"; do
            echo "  - $operation"
        done
        echo ""
    fi
    
    echo "处理的仓库列表:"
    for repo_name in "${!REPOS[@]}"; do
        echo "  - $repo_name: ${REPOS[$repo_name]}"
    done
    echo ""
    
    if [ $ERROR_COUNT -eq 0 ]; then
        log_success "🎉 所有仓库处理完成！"
    else
        log_warning "⚠️  部分仓库处理失败，请检查上述错误信息"
    fi
    echo "=================================================================="
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
        # 处理所有仓库
        process_repos
        
        # 生成摘要报告
        generate_final_summary
    else
        log_error "环境检查失败，终止执行"
        exit 1
    fi
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_time "总执行时间: ${duration}秒"
    
    # 返回执行结果
    if [ $ERROR_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 执行主函数
main "$@"

# ==============================================================================
# 原始代码备份（供参考）
# ==============================================================================

# # 京东云雅典娜led控制

# # lucky by gdy666，自带luci-app，sirpdboy也有luci-app但是可能与原作者有冲突
# git clone  https://github.com/gdy666/luci-app-lucky.git package/luci-app-lucky
# #git clone https://github.com/sirpdboy/luci-app-lucky.git package/luci-app-lucky

# # luci-app-easytier
# git clone https://github.com/EasyTier/luci-app-easytier.git package/luci-app-easytier

# # frp https://github.com/fatedier/frp，无luci-app，建议使用small-package更新

# # homeproxy immortalwrt官方出品，无luci-app，建议使用https://github.com/VIKINGYFY/homeproxy更新
# git clone https://github.com/VIKINGYFY/homeproxy package/luci-app-homeproxy
# #  一个更方便地生成 ImmortalWrt/OpenWrt(23.05.x+) HomeProxy 插件大多数常用配置的脚本。
# # (必备) 通过私密 Gist 或其它可被正常访问的私有链接定制你的专属 rules.sh 配置内容；
# # 执行以下命令（脚本执行期间会向你索要你的定制配置URL）：bash -c "$(curl -fsSl https://raw.githubusercontent.com/thisIsIan-W/homeproxy-autogen-configuration/refs/heads/main/generate_homeproxy_rules.sh)"

# # golang & luci-app-openlist2 by sbwml
# git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
# git clone https://github.com/sbwml/luci-app-openlist2 package/luci-app-openlist2

# # luci-app-mosdns  by sbwml
# git clone -b v5 https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns

# # luci-app-quickfile by sbwml
# git clone https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile

# # luci-app-istorex（向导模式及主体）/luci-app-quickstart（网络向导和首页界面）/luci-app-diskman （磁盘管理），建议使用small-package更新

# # momo在 OpenWrt 上使用 sing-box 进行透明代理/nikki在 OpenWrt 上使用 Mihomo 进行透明代理。
# # echo "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo.git;main" >> "feeds.conf.default"
# # echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"
# git clone https://github.com/nikkinikki-org/OpenWrt-momo package/luci-app-momo
# git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki

# # OpenAppFilter（OAF），自带luci-app
# git clone https://github.com/destan19/OpenAppFilter.git package/luci-app-oaf

# # luci-app-openclash by vernesong
# git clone -b dev https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# # tailscale，官方推荐luci-app-tailscale by asvow
# sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
# git clone https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale

# # vnt，官方https://github.com/vnt-dev/vnt，无luci-app，使用lmq8267
# git clone https://github.com/lmq8267/luci-app-vnt.git package/luci-app-vnt

# # kenzok8/small-package，后备之选，只有上述的ipk地址缺失才会用到。
# git clone https://github.com/kenzok8/small-package small
