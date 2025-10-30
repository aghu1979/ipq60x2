#!/bin/bash
set -e

echo ">>> 开始更新 Feeds..."
for i in {1..3}; do
    echo "  - 尝试第 $i 次更新..."
    ./scripts/feeds update -a && break || sleep 10
done
echo "✅ Feeds 更新完成。"
