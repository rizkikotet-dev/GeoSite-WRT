#!/bin/bash

# Script configuration
VERSION="1.1"
TEMP_DIR="/tmp"
MIHOMO_DIR="/etc/mihomo/run"
OPENCLASH_DIR="/etc/openclash"

setup_colors() {
    PURPLE="\033[95m"
    BLUE="\033[94m"
    GREEN="\033[92m"
    YELLOW="\033[93m"
    RED="\033[91m"
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    RESET="\033[0m"

    STEPS="[${PURPLE} STEPS ${RESET}]"
    INFO="[${BLUE} INFO ${RESET}]"
    SUCCESS="[${GREEN} SUCCESS ${RESET}]"
    WARNING="[${YELLOW} WARNING ${RESET}]"
    ERROR="[${RED} ERROR ${RESET}]"

    # Formatting
    CL=$(echo "\033[m")
    UL=$(echo "\033[4m")
    BOLD=$(echo "\033[1m")
    BFR="\\r\\033[K"
    HOLD=" "
    TAB="  "
}

spinner() {
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local colors=("\033[31m" "\033[33m" "\033[32m" "\033[36m" "\033[34m" "\033[35m" "\033[91m" "\033[92m" "\033[93m" "\033[94m")
    local spin_i=0
    local color_i=0
    local interval=0.1

    if ! sleep $interval 2>/dev/null; then
        interval=1
    fi

    printf "\e[?25l"

    while true; do
        local color="${colors[color_i]}"
        printf "\r ${color}%s${CL}" "${frames[spin_i]}"

        spin_i=$(( (spin_i + 1) % ${#frames[@]} ))
        color_i=$(( (color_i + 1) % ${#colors[@]} ))

        sleep "$interval" 2>/dev/null || sleep 1
    done
}

setup_colors

format_time() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(( (total_seconds % 3600) / 60 ))
  local seconds=$((total_seconds % 60))
  printf "%02d:%02d:%02d" $hours $minutes $seconds
}

cmdinstall() {
    local cmd="$1"
    local desc="${2:-$cmd}"

    echo -ne "${TAB}${HOLD}${INFO} ${desc}${HOLD}"
    spinner &
    SPINNER_PID=$!
    local start_time=$(date +%s)
    local output=$($cmd 2>&1)
    local exit_code=$?
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    local formatted_time=$(format_time $elapsed_time)

    if [ $exit_code -eq 0 ]; then
        if [ -n "$SPINNER_PID" ] && ps | grep $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
        printf "\e[?25h"
        echo -e "${BFR}${SUCCESS} ${desc} ${BLUE}[$formatted_time]${RESET}"
    else
        if [ -n "$SPINNER_PID" ] && ps | grep $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
        printf "\e[?25h"
        echo -e "${BFR}${ERROR} ${desc} ${BLUE}[$formatted_time]${RESET}"
        echo "$output"
        exit 1
    fi
}

# Dependency check with more robust verification
check_dependencies() {
    local commands=("unzip" "tar" "curl" "jq" "coreutils-sleep")
    
    # Determine package manager
    if [ -x "/bin/opkg" ]; then
        echo -e "${INFO} Using OpenWrt package manager (opkg)"
        
        for cmd in "${commands[@]}"; do
            if ! opkg list-installed | grep -q "^$cmd "; then
                echo -e "${INFO} Installing missing dependency: $cmd"
                cmdinstall "opkg update" "Updating package lists" || handle_error "Failed to update package lists"
                cmdinstall "opkg install $cmd" "Installing $cmd"
            else
                echo -e "${SUCCESS} $cmd is already installed"
            fi
        done
        
    elif [ -x "/usr/bin/apk" ]; then
        echo -e "${INFO} Using Alpine package manager (apk)"
        
        for cmd in "${commands[@]}"; do
            if ! apk info -e "$cmd" &>/dev/null; then
                echo -e "${INFO} Installing missing dependency: $cmd"
                cmdinstall "apk update" "Updating package lists" || handle_error "Failed to update package lists"
                cmdinstall "apk add $cmd --allow-untrusted" "Installing $cmd"
            else
                echo -e "${SUCCESS} $cmd is already installed"
            fi
        done
        
    else
        handle_error "No supported package manager found"
    fi
    echo -e "${SUCCESS} All dependencies are installed and available"
}

OpenClash() {
    cmdinstall "curl -L https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geoip.dat -o $OPENCLASH_DIR/GeoIP.dat" "Install GeoIP"
    cmdinstall "curl -L https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geosite.dat -o $OPENCLASH_DIR/GeoSite.dat" "Install GeoSite"
    cmdinstall "curl -L https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/country.mmdb -o $OPENCLASH_DIR/Country.mmdb" "Install Country"

    cmdinstall "uci set openclash.config.geo_custom_url=https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/country.mmdb" "Set Country"
	cmdinstall "uci set openclash.config.geosite_custom_url=https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geosite.dat" "Set GeoSite"
	cmdinstall "uci set openclash.config.geoip_custom_url=https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geoip.dat" "Set GeoIP"
	cmdinstall "uci set openclash.config.geo_auto_update=1" "Set Geo Auto Update"
	cmdinstall "uci set openclash.config.geo_update_week_time=1" "Set Geo Week Time"
	cmdinstall "uci set openclash.config.geo_update_day_time=0" "Set Geo Day Time"
	cmdinstall "uci set openclash.config.geoip_auto_update=1" "Set GeoIP Auto Update"
	cmdinstall "uci set openclash.config.geoip_update_week_time=1" "Set GeoIP Week Time"
	cmdinstall "uci set openclash.config.geoip_update_day_time=0" "Set GeoIP Day Time"
	cmdinstall "uci set openclash.config.geosite_auto_update=1" "Set GeoSite Auto Update"
	cmdinstall "uci set openclash.config.geosite_update_week_time=1" "Set GeoSite Week Time"
	cmdinstall "uci set openclash.config.geosite_update_day_time=0" "Set GeoSite Day Time"
    cmdinstall "uci set openclash.config.geodata_loader=memconservative" "Set Geodata Loader"
	cmdinstall "uci set openclash.config.enable_geoip_dat=1" "Set Enable GeoIP"
    cmdinstall "uci commit openclash" "Commit OpenClash"

    echo -e "${SUCCESS} Configuration installation completed successfully!"
}

Mihomo() {
    cmdinstall "curl -L https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geoip.dat -o $MIHOMO_DIR/GeoIP.dat" "Install GeoIP"
    cmdinstall "curl -L https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geosite.dat -o $MIHOMO_DIR/GeoSite.dat" "Install GeoSite"
    cmdinstall "curl -L https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geoip.metadb -o $MIHOMO_DIR/GeoIP.metadb" "Install GeoMeta"
    
    cmdinstall "uci set mihomo.mixin.geoip_format=dat" "Set GeoIP Format"
	cmdinstall "uci set mihomo.mixin.geodata_loader=memconservative" "Set Geodata Loadder"
	cmdinstall "uci set mihomo.mixin.geosite_url=https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geosite.dat" "Set GeoSite URL"
	cmdinstall "uci set mihomo.mixin.geoip_mmdb_url=https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geoip.metadb" "Set GeoMeta URL"
	cmdinstall "uci set mihomo.mixin.geoip_dat_url=https://github.com/rizkikotet-dev/GeoSite-WRT/releases/download/latest/geoip.dat" "Set GeoIP URL"
	cmdinstall "uci set mihomo.mixin.geox_auto_update=1" "Set GeoX Auto Udate"
	cmdinstall "uci set mihomo.mixin.geox_update_interval=24" "Set GeoX Interval"
    cmdinstall "uci commit mihomo" "Commit Mihomo"

    echo -e "${SUCCESS} Configuration installation completed successfully!"
}

display_menu() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════${RESET}"
    echo -e "${PURPLE}       Auto Script | GeoSite Updater       ${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════${RESET}"
    echo -e " Version : ${GREEN}${VERSION}${RESET}"
    echo -e " Created : ${GREEN}RizkiKotet${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════${RESET}"
    echo -e " ${YELLOW}1.${RESET} Install / Update Untuk ${GREEN}OpenClash${RESET}"
    echo -e " ${YELLOW}2.${RESET} Install / Update Untuk ${GREEN}Mihomo${RESET}"
    echo -e " ${YELLOW}x.${RESET} Keluar"
    echo -e "${CYAN}═══════════════════════════════════════════${RESET}"
    echo -e " Notes:"
    echo -e " - Ini hanya untuk Update / Install"
    echo -e " - Untuk menerapkannya silahkan lihat di GitHub"
    echo -e "${CYAN}═══════════════════════════════════════════${RESET}"
}

main() {
    while true; do
        display_menu
        read -rp " Pilih opsi: " choice

        case "$choice" in
            1) 
            echo -e "${INFO} Memulai Install/Update untuk OpenClash..." 
            check_dependencies
            OpenClash
            ;;
            2) 
            echo -e "${INFO} Memulai Install/Update untuk Mihomo..." 
            check_dependencies
            Mihomo
            ;;
            [xX]) echo -e "${INFO} Keluar..."; exit 0 ;;
            *) echo -e "${WARNING} Pilihan tidak valid!" ;;
        esac

        read -rp " Tekan Enter untuk melanjutkan..."
    done
}

main