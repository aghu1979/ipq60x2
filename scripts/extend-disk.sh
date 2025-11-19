# scripts/extend-disk.sh
# =============================================================================
# 使用软链接扩展磁盘空间，避免编译过程中磁盘空间不足
# 版本: 1.0.0
# 更新日期: 2025-11-19
# =============================================================================

echo "开始扩展磁盘空间..."

# 显示当前磁盘使用情况
echo "当前磁盘使用情况:"
df -h

# 创建一个临时目录用于存放编译文件
# /tmp目录通常挂载在更大的分区上或者使用tmpfs
TEMP_BUILD_DIR="/tmp/immwrt-build"
sudo mkdir -p "$TEMP_BUILD_DIR"
sudo chown $USER:$GROUPS "$TEMP_BUILD_DIR"

# 创建软链接，将/workdir指向临时目录
# 这样后续所有对/workdir的操作都会在空间更大的/tmp下进行
sudo ln -sfT "$TEMP_BUILD_DIR" /workdir

# 显示扩展后的磁盘使用情况
echo "磁盘空间扩展完成，当前使用情况:"
df -h

echo "工作目录 /workdir 已成功链接到 $TEMP_BUILD_DIR"
