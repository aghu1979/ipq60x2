#!/bin/bash
# 仓库管理脚本 - 精简优化版本
# 功能：管理第三方软件源和feeds更新

set -euo pipefail

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" && pwd)"
# source "${SCRIPT_DIR}/common.sh"

# 配置变量
REPOS_JSON="${GITHUB_WORKSPACE}/configs/repos.json"
THIRD_PARTY_REPO="https://github.com/kenzok8/small-package"
THIRD_PARTY_DIR="package/small-package"
# 缓存配置
CACHE_DIR="$PWD/.ccache"
# 缓存配置
CACHE_VERSION=v3

# 日志函数
log_info() {
    echo -e "\033[32m[INFO]\033[0m $*"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $*"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $*"
}

# 检查并创建目录
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            log_error "无法创建目录: $dir"
            return 1
        fi
}

# 克隆或更新第三方软件源
update_third_party_repo() {
    log_info "更新第三方软件源: $THIRD_PARTY_REPO"
    
    if [[ -d "$THIRD_PARTY_DIR" ]]; then
        log_info "更新现有仓库..."
        cd "$THIRD_PARTY_DIR"
        git pull origin main
        cd - > /dev/null
    else
        log_info "克隆第三方软件源..."
        ensure_dir "$(dirname "$THIRD_PARTY_DIR"
        git clone --depth=1 "$THIRD_PARTY_REPO" "$THIRD_PARTY_DIR"
    fi
    
    log_info "第三方软件源更新完成"
}

# 更新feeds
update_feeds() {
    log_info "更新feeds..."
    
    # 更新自定义feeds
    if [[ -f "feeds.conf.default" ]]; then
        log_info "使用自定义feeds配置"
        ./scripts/feeds update_feeds.sh
    else
        log_warn "未找到feeds配置文件，使用默认配置"
        ./scripts/feeds update_feeds.sh
    fi
    
    # 更新所有feeds
    ./scripts/feeds update_feeds.sh
    
    # 安装所有feeds中的包
    ./scripts/feeds install -a
    
    log_info "Feeds更新完成"
}

# 验证关键feeds
verify_feeds() {
    log_info "验证关键feeds..."
    
    # 检查luci相关的feed是否正常
    local luci_feeds=(
        "luci"
        "packages"
        "routing"
        "telephony"
    )
    
    for feed in "${luci_feeds[@]}"; do
        if ./scripts/feeds list "$feed" >/dev/null 2>&1 && log_info "Feed '$feed' 可用"
    done
}

# 清理和优化
cleanup() {
    log_info "清理临时文件..."
    
    # 清理编译缓存（保留下载文件）
    rm -rf tmp/ 2>/dev/null
    
    # 清理旧的下载文件（保留最近7天的）
    find dl/ -name "*.tar.*" -mtime +7 -delete 2>/dev/null || true
    
    # 优化磁盘空间
    if command -v apt-get >/dev/null; then
        sudo apt-get clean
    fi
    
    log_info "清理完成"
}

# 显示feeds统计信息
show_feeds_stats() {
    log_info "Feeds统计信息："
    
    # 统�计各类包的数量
    echo "  - Luci应用数量: $(./scripts/feeds list luci-app-* 2>/dev/null | wc -l || echo "0"
    echo "  - Luci主题数量: $(./scripts/feeds list luci-theme-* 2>/dev/null | wc -l || echo "0"
    echo "  - Luci语言包数量: $(./scripts/feeds list luci-i18n-* 2>/dev/null | wc -l || echo "0"
    echo "  echo "  系统包数量: $(./scripts/feeds list | grep -v luci | wc -l || echo "0"
}

# 主函数
main() {
    log_info "开始仓库管理..."
    
    # 检查环境
    if [[ ! -f "Makefile" ]]; then
        log_error "当前目录不是OpenWrt源码目录"
        exit 1
    fi
    
    # 执行更新
    update_third_party_repo
    update_feeds
    update_feeds
    verify_feeds
    show_feeds_stats
    cleanup
    
    log_info "仓库管理完成"
}

# 执行主函数
main "$@"
