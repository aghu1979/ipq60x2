#!/bin/bash
set -e

# =============================================================================
# DIY Part 1 & 2 Script
# =============================================================================

# --- Configuration for P1 ---
# Custom feeds to add
CUSTOM_FEEDS=(
    "src-git small https://github.com/kenzok8/small-package"
)
# Custom packages to clone
declare -A CUSTOM_PACKAGES=(
    ["luci-app-openclash"]="https://github.com/vernesong/OpenClash.git"
)

# --- Configuration for P2 ---
# Default system settings
DEFAULT_HOSTNAME="WRT"
DEFAULT_IP_ADDR="192.168.111.1"
# --- End of Configuration ---


case "$1" in
"P1")
    echo ">>> DIY Part 1: Adding custom feeds and packages"
    # Add custom feeds
    for feed in "${CUSTOM_FEEDS[@]}"; do
        echo "Adding feed: $feed"
        echo "$feed" >> feeds.conf.default
    done

    # Clone custom packages
    for pkg_dir in "${!CUSTOM_PACKAGES[@]}"; do
        pkg_url="${CUSTOM_PACKAGES[$pkg_dir]}"
        echo "Cloning package '$pkg_dir' from '$pkg_url'"
        rm -rf "package/$pkg_dir"
        if ! git clone "$pkg_url" "package/$pkg_dir"; then
            echo "错误: 克隆包 $pkg_dir 失败!" >&2
            exit 1
        fi
    done
    ;;
"P2")
    echo ">>> DIY Part 2: Applying default system settings"
    # Modify default settings
    sed -i "s/OpenWrt/$DEFAULT_HOSTNAME/g" package/base-files/files/bin/config_generate
    sed -i "s/192.168.1.1/$DEFAULT_IP_ADDR/g" package/base-files/files/bin/config_generate
    
    # Set root password to empty
    echo "Setting root password to empty..."
    mkdir -p files/etc
    cat > files/etc/shadow <<EOF
root:::0:99999:7:::
daemon:*:0:0:99999:7:::
adm:*:0:0:99999:7:::
mail:*:0:0:99999:7:::
ftp:*:0:0:99999:7:::
nobody:*:0:0:99999:7:::
EOF

    # Rename device name (merged from old device_rename.sh)
    NETWORK_CONFIG_FILE="target/linux/ipq60xx/base-files/etc/board.d/02_network"
    declare -A DEVICE_RENAME_MAP=(
        ["ipq60xx-ax6000"]="IPQ60xx-AX6000"
    )
    if [ -f "$NETWORK_CONFIG_FILE" ]; then
        echo "Modifying device names in $NETWORK_CONFIG_FILE"
        for old_name in "${!DEVICE_RENAME_MAP[@]}"; do
            new_name="${DEVICE_RENAME_MAP[$old_name]}"
            echo "  - Renaming '$old_name' to '$new_name'"
            sed -i "s/$old_name/$new_name/g" "$NETWORK_CONFIG_FILE"
        done
    else
        echo "Warning: File $NETWORK_CONFIG_FILE not found. Skipping device rename." >&2
    fi
    ;;
*)
    echo "用法: $0 {P1|P2}" >&2
    exit 1
    ;;
esac
