# ImmortalWrt IPQ60xx 自动化构建项目

[![Build Status](https://github.com/laipeng668/immortalwrt/actions/workflows/immu.yml/badge.svg)](https://github.com/laipeng668/immortalwrt/actions/workflows/immu.yml)
[![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](LICENSE)

## 项目简介

本项目提供了一套完整的 ImmortalWrt 固件自动化构建解决方案，专为 IPQ60xx 平台设计。通过 GitHub Actions 实现云端编译，支持多种设备型号，集成丰富的第三方软件包，并提供详细的构建报告。

## 主要特性

### 🚀 自动化构建
- 基于 GitHub Actions 的云端编译
- 支持手动触发和自动触发
- 智能缓存管理，提高构建效率
- 自动磁盘空间扩展

### 📦 丰富的软件包
- 集成多个第三方软件源
- 包含网络代理、文件管理、系统监控等应用
- 支持 Ultra 和 Max 两种构建变体
- 自动处理软件包冲突

### 📊 详细报告
- LUCI 软件包变更报告
- 构建过程摘要
- 失败操作追踪
- 磁盘使用监控

### 🎨 定制化配置
- 自定义初始网络设置
- 系统性能优化
- Argon 主题美化
- BBR 拥塞控制算法

## 支持的设备

| 设备型号 | 代码名称 | 状态 |
|---------|---------|------|
| 京东云无线宝 亚瑟 | jdcloud_re-ss-01 | ✅ 支持 |
| 京东云无线宝 雅典娜 | jdcloud_re-cs-02 | ✅ 支持 |

## 文件结构
