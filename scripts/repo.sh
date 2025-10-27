#!/bin/bash

# 设置日志函数
log() {
  echo -e "\033[1;34m[INFO]\033[0m $1"
}

error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
  exit 1
}

warning() {
  echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# 添加第三方软件源仓库
log "添加第三方软件源仓库..."
git clone https://github.com/kenzok8/small-package package/small-package || error "克隆small-package仓库失败"

# 添加软件源到feeds.conf.default
if [ -f "feeds.conf.default" ]; then
  echo "src-link small_package package/small-package" >> feeds.conf.default || error "添加软件源到feeds.conf.default失败"
  log "已添加small-package软件源到feeds.conf.default"
else
  warning "未找到feeds.conf.default文件"
fi

log "第三方软件源添加完成"
