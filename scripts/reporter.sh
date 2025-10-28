#!/bin/bash

# 报告生成脚本

generate_report() {
    local build_status="$1"
    local build_id="$2"
    
    source "$LOGGER_SCRIPT"
    step_start "GEN_REPORT" "生成构建报告"
    
    # 确保报告文件存在
    if [ ! -f "$REPORT_FILE" ]; then
        echo '{"build_id":"'$build_id'","start_time":"'$(date -Iseconds)'","steps":[],"errors":[],"warnings":[],"build_errors":[]}' > "$REPORT_FILE"
    fi
    
    # 完成报告
    jq --arg time "$(date -Iseconds)" --arg status "$build_status" \
        '.end_time = $time | .status = $status' "$REPORT_FILE" > "$REPORT_FILE.tmp" && \
        mv "$REPORT_FILE.tmp" "$REPORT_FILE" 2>/dev/null || true
    
    # 生成摘要报告
    {
        echo "=== 构建摘要 ==="
        echo "构建ID: $build_id"
        echo "仓库: $REPO_URL"
        echo "分支: $REPO_BRANCH"
        echo "芯片: $CHIP_FAMILY"
        echo "设备: $DEVICE_NAMES"
        echo "状态: $build_status"
        echo "开始时间: $(jq -r '.start_time' "$REPORT_FILE" 2>/dev/null || echo "未知")"
        echo "结束时间: $(date -Iseconds)"
        echo ""
        echo "=== 缓存状态 ==="
        echo "工具链缓存: $CACHE_STATUS_TOOLCHAIN"
        echo "Feeds缓存: $CACHE_STATUS_FEEDS"
        echo "DL缓存: $CACHE_STATUS_DL"
        echo ""
        echo "=== 错误统计 ==="
        echo "错误数量: $(jq '.errors | length' "$REPORT_FILE" 2>/dev/null || echo "0")"
        echo "警告数量: $(jq '.warnings | length' "$REPORT_FILE" 2>/dev/null || echo "0")"
        echo "构建错误数量: $(jq '.build_errors | length' "$REPORT_FILE" 2>/dev/null || echo "0")"
        echo ""
        if [ "$(jq '.build_errors | length' "$REPORT_FILE" 2>/dev/null || echo "0")" -gt 0 ]; then
            echo "=== 构建错误详情 ==="
            jq -r '.build_errors[] | "- [\(.time)] \(.package): \(.message)"' "$REPORT_FILE" 2>/dev/null || echo "无构建错误"
            echo ""
        fi
        if [ "$(jq '.errors | length' "$REPORT_FILE" 2>/dev/null || echo "0")" -gt 0 ]; then
            echo "=== 其他错误详情 ==="
            jq -r '.errors[] | "- [\(.time)] \(.step): \(.message)"' "$REPORT_FILE" 2>/dev/null || echo "无其他错误"
            echo ""
        fi
        if [ "$(jq '.warnings | length' "$REPORT_FILE" 2>/dev/null || echo "0")" -gt 0 ]; then
            echo "=== 警告详情 ==="
            jq -r '.warnings[] | "- [\(.time)] \(.step): \(.message)"' "$REPORT_FILE" 2>/dev/null || echo "无警告"
            echo ""
        fi
    } > "$GITHUB_WORKSPACE/build_summary.txt"
    
    log "INFO" "构建报告已生成"
    cat "$GITHUB_WORKSPACE/build_summary.txt"
    
    step_complete "GEN_REPORT" "success"
}

check_disk_space() {
    source "$LOGGER_SCRIPT"
    step_start "CHECK_SPACE" "检查磁盘空间"
    
    log "INFO" "=== 磁盘空间使用情况 ==="
    df -hT
    
    log "INFO" "=== 目录大小统计 ==="
    for dir in "bin" "staging_dir" ".ccache" "feeds" "dl"; do
        if [ -d "$OPENWRT_PATH/$dir" ]; then
            size=$(du -sh "$OPENWRT_PATH/$dir" | cut -f1)
            log "INFO" "$dir: $size"
        fi
    done
    
    step_complete "CHECK_SPACE" "success"
}

# 导出函数
export -f generate_report check_disk_space
