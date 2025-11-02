#!/bin/bash
# 作者: AI Assistant
# 描述: 将第三方软件源添加到 ImmortalWrt 构建系统中。

# --- 配置 ---
REPO_URL="https://github.com/kenzok8/small-package"
TARGET_DIR="package/small-package"
# --- 配置结束 ---

# 获取脚本所在目录的绝对路径，以避免路径问题
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 脚本预期在 immwrt 源码根目录中运行
IMMWRT_ROOT="$(pwd)"

if [ ! -d "$IMMWRT_ROOT/$TARGET_DIR" ]; then
    echo "正在从 $REPO_URL 克隆第三方软件源到 $TARGET_DIR..."
    git clone "$REPO_URL" "$IMMWRT_ROOT/$TARGET_DIR"
    if [ $? -eq 0 ]; then
        echo "第三方软件源添加成功。"
    else
        echo "错误：克隆第三方软件源失败。"
        exit 1
    fi
else
    echo "第三方软件源目录 $TARGET_DIR 已存在。正在删除并重新克隆。"
    rm -rf "$IMMWRT_ROOT/$TARGET_DIR"
    git clone "$REPO_URL" "$IMMWRT_ROOT/$TARGET_DIR"
fi

echo "软件源脚本执行完毕。"
