#!/bin/bash

# 变量生成脚本

generate_variables() {
    local chip_family="$1"
    local repo_short="$2"
    local repo_url="$3"
    
    source "$LOGGER_SCRIPT"
    source "${GITHUB_WORKSPACE}/scripts/common.sh"
    step_start "GEN_VARS" "生成构建变量"
    
    cd "$GITHUB_WORKSPACE"
    
    # 查找配置文件
    log "INFO" "查找基础配置文件..."
    CONFIG_BASE=$(find_config_file "base_${chip_family}")
    if [ $? -ne 0 ]; then
        log "ERROR" "基础配置文件不存在: base_${chip_family}"
        exit 1
    fi
    
    log "INFO" "查找分支配置文件..."
    CONFIG_BRANCH=$(find_config_file "base_${repo_short}")
    if [ $? -ne 0 ]; then
        log "ERROR" "分支配置文件不存在: base_${repo_short}"
        exit 1
    fi
    
    # 设置脚本路径
    DIY_SCRIPT="${GITHUB_WORKSPACE}/${DIY_SCRIPT_DIR}/diy.sh"
    REPO_SCRIPT="${GITHUB_WORKSPACE}/${DIY_SCRIPT_DIR}/repo.sh"
    
    log "INFO" "基础配置文件: $CONFIG_BASE"
    log "INFO" "分支配置文件: $CONFIG_BRANCH"
    log "INFO" "自定义脚本: $DIY_SCRIPT"
    log "INFO" "软件源脚本: $REPO_SCRIPT"
    
    echo "CONFIG_BASE=$CONFIG_BASE" >> $GITHUB_ENV
    echo "CONFIG_BRANCH=$CONFIG_BRANCH" >> $GITHUB_ENV
    echo "DIY_SCRIPT=$DIY_SCRIPT" >> $GITHUB_ENV
    echo "REPO_SCRIPT=$REPO_SCRIPT" >> $GITHUB_ENV
    
    # 提取设备信息
    log "INFO" "提取设备信息..."
    cp "$CONFIG_BASE" "$OPENWRT_PATH/.config" || {
        log "ERROR" "复制配置文件失败"
        exit 1
    }
    
    cd "$OPENWRT_PATH"
    if ! make defconfig > /dev/null 2>&1; then
        log "ERROR" "运行defconfig失败"
        exit 1
    fi
    
    SOURCE_REPO="$(echo "$repo_url" | awk -F '/' '{print $(NF)}')"
    DEVICE_TARGET=$(cat .config | grep CONFIG_TARGET_BOARD | awk -F '"' '{print $2}')
    DEVICE_SUBTARGET=$(cat .config | grep CONFIG_TARGET_SUBTARGET | awk -F '"' '{print $2}')
    DEVICE_NAMES=$(grep -oP "CONFIG_TARGET_DEVICE_.*_${chip_family}_DEVICE_\K[^=]+" "$CONFIG_BASE" | tr '\n' ' ')
    
    echo "SOURCE_REPO=$SOURCE_REPO" >> $GITHUB_ENV
    echo "DEVICE_TARGET=$DEVICE_TARGET" >> $GITHUB_ENV
    echo "DEVICE_SUBTARGET=$DEVICE_SUBTARGET" >> $GITHUB_ENV
    echo "DEVICE_NAMES=$DEVICE_NAMES" >> $GITHUB_ENV
    
    # 生成哈希值
    CONFIG_HASH=$(cat "$CONFIG_BASE" "$CONFIG_BRANCH" | sha256sum | cut -d' ' -f1)
    FEEDS_HASH=$(cat "$OPENWRT_PATH/feeds.conf.default" 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "default")
    
    echo "CONFIG_HASH=$CONFIG_HASH" >> $GITHUB_ENV
    echo "FEEDS_HASH=$FEEDS_HASH" >> $GITHUB_ENV
    
    log "INFO" "设备目标: $DEVICE_TARGET"
    log "INFO" "设备子目标: $DEVICE_SUBTARGET"
    log "INFO" "设备名称: $DEVICE_NAMES"
    
    step_complete "GEN_VARS" "success"
}

# 导出函数
export -f generate_variables
