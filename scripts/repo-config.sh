#!/bin/bash

# 仓库配置读取脚本

read_repo_config() {
    local repo_config="$1"
    
    source "$LOGGER_SCRIPT"
    step_start "READ_CONFIG" "读取仓库配置"
    
    cd "$GITHUB_WORKSPACE"
    
    # 检查仓库配置文件
    REPO_CONFIG_FILE="${GITHUB_WORKSPACE}/${CONFIG_BASE_DIR}/repos.json"
    if [ ! -f "$REPO_CONFIG_FILE" ]; then
        log "ERROR" "仓库配置文件不存在: $REPO_CONFIG_FILE"
        exit 1
    fi
    
    log "INFO" "读取仓库配置: $repo_config"
    REPO_INFO=$(jq -r --arg repo "$repo_config" '.[$repo]' "$REPO_CONFIG_FILE")
    
    if [ "$REPO_INFO" = "null" ]; then
        log "ERROR" "未找到仓库配置: $repo_config"
        exit 1
    fi
    
    REPO_URL=$(echo "$REPO_INFO" | jq -r '.url')
    REPO_BRANCH=$(echo "$REPO_INFO" | jq -r '.branch')
    REPO_SHORT=$(echo "$REPO_INFO" | jq -r '.short')
    
    echo "REPO_URL=$REPO_URL" >> $GITHUB_ENV
    echo "REPO_BRANCH=$REPO_BRANCH" >> $GITHUB_ENV
    echo "REPO_SHORT=$REPO_SHORT" >> $GITHUB_ENV
    
    log "INFO" "仓库URL: $REPO_URL"
    log "INFO" "分支: $REPO_BRANCH"
    log "INFO" "简称: $REPO_SHORT"
    
    step_complete "READ_CONFIG" "success"
}

# 导出函数
export -f read_repo_config
