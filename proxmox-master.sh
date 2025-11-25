#!/bin/bash

#############################################
# Proxmox Master Management Script
# One-click menu for managing Proxmox services
#############################################

# Color codes for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
IS_CLUSTER=false
CLUSTER_NAME=""
NODE_NAME=$(hostname)

# Base Proxmox services (always present)
BASE_SERVICES=(
    "pvedaemon"
    "pveproxy"
    "pvestatd"
    "pve-firewall"
)

# Cluster-only services
CLUSTER_SERVICES=(
    "pve-cluster"
    "pve-ha-lrm"
    "pve-ha-crm"
    "corosync"
)

# Combined array (will be set based on cluster detection)
PROXMOX_SERVICES=()

# Function to detect cluster mode
detect_cluster() {
    if [ -f /etc/pve/corosync.conf ] && [ -f /etc/corosync/corosync.conf ]; then
        IS_CLUSTER=true

        # Try multiple methods to get cluster name
        # Method 1: Parse from corosync.conf file
        CLUSTER_NAME=$(grep -oP 'cluster_name:\s*\K\S+' /etc/pve/corosync.conf 2>/dev/null)

        # Method 2: Try pvecm status with different patterns
        if [ -z "$CLUSTER_NAME" ]; then
            CLUSTER_NAME=$(pvecm status 2>/dev/null | grep -i "cluster name" | awk -F': ' '{print $2}' | tr -d ' ')
        fi

        # Method 3: Try alternative pvecm parsing
        if [ -z "$CLUSTER_NAME" ]; then
            CLUSTER_NAME=$(pvecm status 2>/dev/null | awk '/Cluster name:/ {print $3}')
        fi

        # Method 4: Parse corosync.conf with awk
        if [ -z "$CLUSTER_NAME" ]; then
            CLUSTER_NAME=$(awk '/cluster_name:/ {print $2}' /etc/pve/corosync.conf 2>/dev/null)
        fi

        # Fallback if all methods fail
        [ -z "$CLUSTER_NAME" ] && CLUSTER_NAME="Unknown"

        PROXMOX_SERVICES=("${BASE_SERVICES[@]}" "${CLUSTER_SERVICES[@]}")
    else
        IS_CLUSTER=false
        PROXMOX_SERVICES=("${BASE_SERVICES[@]}")
    fi
}

# Function to print header
print_header() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}     Proxmox Master Management Script${NC}"
    echo -e "${BLUE}================================================${NC}"
    if [ "$IS_CLUSTER" = true ]; then
        echo -e "${CYAN}Mode: Cluster${NC} | ${MAGENTA}Cluster Name: $CLUSTER_NAME${NC}"
        echo -e "${CYAN}Node: $NODE_NAME${NC}"
    else
        echo -e "${CYAN}Mode: Standalone${NC} | ${MAGENTA}Node: $NODE_NAME${NC}"
    fi
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Function to check status of all services
check_status() {
    print_header
    echo -e "${YELLOW}Checking status of all Proxmox services...${NC}"
    echo ""

    if [ "$IS_CLUSTER" = true ]; then
        echo -e "${CYAN}Mode: Cluster - Checking all services (Base + Cluster)${NC}"
    else
        echo -e "${CYAN}Mode: Standalone - Checking base services only${NC}"
    fi
    echo ""

    echo -e "${BLUE}=== Base Services ===${NC}"
    for service in "${BASE_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}✓${NC} $service: ${GREEN}ACTIVE${NC}"
        else
            echo -e "${RED}✗${NC} $service: ${RED}INACTIVE${NC}"
        fi
    done

    if [ "$IS_CLUSTER" = true ]; then
        echo ""
        echo -e "${BLUE}=== Cluster Services ===${NC}"
        for service in "${CLUSTER_SERVICES[@]}"; do
            if systemctl is-active --quiet "$service"; then
                echo -e "${GREEN}✓${NC} $service: ${GREEN}ACTIVE${NC}"
            else
                echo -e "${RED}✗${NC} $service: ${RED}INACTIVE${NC}"
            fi
        done
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Function to start all services
start_services() {
    print_header
    echo -e "${YELLOW}Starting all Proxmox services...${NC}"
    echo ""

    if [ "$IS_CLUSTER" = true ]; then
        echo -e "${CYAN}Mode: Cluster - Starting all services${NC}"
    else
        echo -e "${CYAN}Mode: Standalone - Starting base services${NC}"
    fi
    echo ""

    echo -e "${BLUE}=== Starting Base Services ===${NC}"
    for service in "${BASE_SERVICES[@]}"; do
        echo -n "Starting $service... "
        if systemctl start "$service" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    done

    if [ "$IS_CLUSTER" = true ]; then
        echo ""
        echo -e "${BLUE}=== Starting Cluster Services ===${NC}"
        for service in "${CLUSTER_SERVICES[@]}"; do
            echo -n "Starting $service... "
            if systemctl start "$service" 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${RED}FAILED${NC}"
            fi
        done
    fi

    echo ""
    echo -e "${GREEN}Operation completed!${NC}"
    read -p "Press Enter to continue..."
}

# Function to stop all services
stop_services() {
    print_header
    echo -e "${RED}WARNING: This will stop all Proxmox services!${NC}"

    if [ "$IS_CLUSTER" = true ]; then
        echo -e "${RED}WARNING: This node is part of a cluster!${NC}"
        echo -e "${YELLOW}Stopping cluster services may affect HA and cluster operations.${NC}"
    fi

    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Operation cancelled."
        sleep 2
        return
    fi

    echo ""
    echo -e "${YELLOW}Stopping all Proxmox services...${NC}"
    echo ""

    # Stop cluster services first (in reverse order)
    if [ "$IS_CLUSTER" = true ]; then
        echo -e "${BLUE}=== Stopping Cluster Services ===${NC}"
        for ((idx=${#CLUSTER_SERVICES[@]}-1 ; idx>=0 ; idx--)); do
            service="${CLUSTER_SERVICES[idx]}"
            echo -n "Stopping $service... "
            if systemctl stop "$service" 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${RED}FAILED${NC}"
            fi
        done
        echo ""
    fi

    # Then stop base services (in reverse order)
    echo -e "${BLUE}=== Stopping Base Services ===${NC}"
    for ((idx=${#BASE_SERVICES[@]}-1 ; idx>=0 ; idx--)); do
        service="${BASE_SERVICES[idx]}"
        echo -n "Stopping $service... "
        if systemctl stop "$service" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    done

    echo ""
    echo -e "${GREEN}Operation completed!${NC}"
    read -p "Press Enter to continue..."
}

# Function to restart all services
restart_services() {
    print_header
    echo -e "${YELLOW}Restarting all Proxmox services...${NC}"
    echo ""

    if [ "$IS_CLUSTER" = true ]; then
        echo -e "${CYAN}Mode: Cluster - Restarting all services${NC}"
        echo -e "${YELLOW}Note: Cluster services will be restarted, this may briefly affect cluster communication.${NC}"
    else
        echo -e "${CYAN}Mode: Standalone - Restarting base services${NC}"
    fi
    echo ""

    echo -e "${BLUE}=== Restarting Base Services ===${NC}"
    for service in "${BASE_SERVICES[@]}"; do
        echo -n "Restarting $service... "
        if systemctl restart "$service" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    done

    if [ "$IS_CLUSTER" = true ]; then
        echo ""
        echo -e "${BLUE}=== Restarting Cluster Services ===${NC}"
        for service in "${CLUSTER_SERVICES[@]}"; do
            echo -n "Restarting $service... "
            if systemctl restart "$service" 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${RED}FAILED${NC}"
            fi
        done
    fi

    echo ""
    echo -e "${GREEN}Operation completed!${NC}"
    read -p "Press Enter to continue..."
}

# Function to manage individual service
manage_individual() {
    while true; do
        print_header
        echo -e "${YELLOW}Manage Individual Service${NC}"
        echo ""

        if [ "$IS_CLUSTER" = true ]; then
            echo -e "${CYAN}Mode: Cluster${NC}"
        else
            echo -e "${CYAN}Mode: Standalone${NC}"
        fi
        echo ""

        echo -e "${BLUE}=== Base Services ===${NC}"
        local counter=1
        for i in "${!BASE_SERVICES[@]}"; do
            service="${BASE_SERVICES[$i]}"
            if systemctl is-active --quiet "$service"; then
                status="${GREEN}[ACTIVE]${NC}"
            else
                status="${RED}[INACTIVE]${NC}"
            fi
            echo -e "$counter. $service $status"
            ((counter++))
        done

        if [ "$IS_CLUSTER" = true ]; then
            echo ""
            echo -e "${BLUE}=== Cluster Services ===${NC}"
            for i in "${!CLUSTER_SERVICES[@]}"; do
                service="${CLUSTER_SERVICES[$i]}"
                if systemctl is-active --quiet "$service"; then
                    status="${GREEN}[ACTIVE]${NC}"
                else
                    status="${RED}[INACTIVE]${NC}"
                fi
                echo -e "$counter. $service $status"
                ((counter++))
            done
        fi

        echo ""
        echo "0. Back to menu"
        echo ""
        read -p "Select service number: " service_num

        if [ "$service_num" = "0" ]; then
            break
        fi

        # Calculate which service was selected
        if [ "$service_num" -ge 1 ] && [ "$service_num" -le "${#BASE_SERVICES[@]}" ]; then
            selected_service="${BASE_SERVICES[$((service_num-1))]}"
            manage_service_submenu "$selected_service"
        elif [ "$IS_CLUSTER" = true ] && [ "$service_num" -gt "${#BASE_SERVICES[@]}" ] && [ "$service_num" -lt "$counter" ]; then
            cluster_idx=$((service_num - ${#BASE_SERVICES[@]} - 1))
            selected_service="${CLUSTER_SERVICES[$cluster_idx]}"
            manage_service_submenu "$selected_service"
        else
            echo -e "${RED}Invalid selection${NC}"
            sleep 1
        fi
    done
}

# Function for service submenu
manage_service_submenu() {
    local service=$1

    while true; do
        print_header
        echo -e "${YELLOW}Managing: $service${NC}"
        echo ""

        if systemctl is-active --quiet "$service"; then
            echo -e "Status: ${GREEN}ACTIVE${NC}"
        else
            echo -e "Status: ${RED}INACTIVE${NC}"
        fi

        echo ""
        echo "1. Start"
        echo "2. Stop"
        echo "3. Restart"
        echo "4. Status (detailed)"
        echo "0. Back"
        echo ""
        read -p "Select action: " action

        case $action in
            1)
                echo ""
                systemctl start "$service"
                echo -e "${GREEN}Service started${NC}"
                sleep 2
                ;;
            2)
                echo ""
                systemctl stop "$service"
                echo -e "${YELLOW}Service stopped${NC}"
                sleep 2
                ;;
            3)
                echo ""
                systemctl restart "$service"
                echo -e "${GREEN}Service restarted${NC}"
                sleep 2
                ;;
            4)
                echo ""
                systemctl status "$service"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection${NC}"
                sleep 1
                ;;
        esac
    done
}

# Function to enable/disable services at boot
manage_boot() {
    print_header
    echo -e "${YELLOW}Manage Services at Boot${NC}"
    echo ""
    echo "1. Enable all services at boot"
    echo "2. Disable all services at boot"
    echo "3. Show boot status"
    echo "0. Back to main menu"
    echo ""
    read -p "Select option: " boot_option

    case $boot_option in
        1)
            echo ""
            for service in "${PROXMOX_SERVICES[@]}"; do
                echo -n "Enabling $service... "
                if systemctl enable "$service" 2>/dev/null; then
                    echo -e "${GREEN}OK${NC}"
                else
                    echo -e "${RED}FAILED${NC}"
                fi
            done
            echo ""
            read -p "Press Enter to continue..."
            ;;
        2)
            echo ""
            for service in "${PROXMOX_SERVICES[@]}"; do
                echo -n "Disabling $service... "
                if systemctl disable "$service" 2>/dev/null; then
                    echo -e "${GREEN}OK${NC}"
                else
                    echo -e "${RED}FAILED${NC}"
                fi
            done
            echo ""
            read -p "Press Enter to continue..."
            ;;
        3)
            echo ""
            for service in "${PROXMOX_SERVICES[@]}"; do
                if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                    echo -e "$service: ${GREEN}ENABLED${NC}"
                else
                    echo -e "$service: ${RED}DISABLED${NC}"
                fi
            done
            echo ""
            read -p "Press Enter to continue..."
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid selection${NC}"
            sleep 1
            ;;
    esac
}

# Troubleshooting menu
troubleshooting_menu() {
    while true; do
        print_header
        echo -e "${YELLOW}Troubleshooting & Diagnostics${NC}"
        echo ""
        echo -e "${BLUE}=== Service Management ===${NC}"
        echo "1.  Check all services status"
        echo "2.  Start all services"
        echo "3.  Stop all services"
        echo "4.  Restart all services"
        echo "5.  Manage individual service"
        echo "6.  Manage services at boot"
        echo ""
        echo -e "${BLUE}=== System Diagnostics ===${NC}"
        echo "7.  System resource check (CPU/RAM/Disk)"
        echo "8.  View recent service errors"
        echo "9.  Check cluster status"
        echo "10. Check storage status"
        echo "11. Check network connectivity"
        echo "12. View system logs (last 50 lines)"
        echo "13. Check Proxmox version"
        echo "14. Test cluster quorum"
        echo "15. Check failed services"
        echo "16. View journal for Proxmox services"
        echo "17. Check VM/Container status"
        echo "18. Generate full diagnostic report"
        echo ""
        echo "0.  Back to main menu"
        echo ""
        read -p "Select option: " ts_option

        case $ts_option in
            1)
                check_status
                ;;
            2)
                start_services
                ;;
            3)
                stop_services
                ;;
            4)
                restart_services
                ;;
            5)
                manage_individual
                ;;
            6)
                manage_boot
                ;;
            7)
                check_system_resources
                ;;
            8)
                view_service_errors
                ;;
            9)
                check_cluster_status
                ;;
            10)
                check_storage_status
                ;;
            11)
                check_network
                ;;
            12)
                view_system_logs
                ;;
            13)
                check_proxmox_version
                ;;
            14)
                test_cluster_quorum
                ;;
            15)
                check_failed_services
                ;;
            16)
                view_service_journal
                ;;
            17)
                check_vm_container_status
                ;;
            18)
                generate_diagnostic_report
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection${NC}"
                sleep 1
                ;;
        esac
    done
}

# Function to check system resources
check_system_resources() {
    print_header
    echo -e "${YELLOW}System Resource Check${NC}"
    echo ""

    echo -e "${BLUE}=== CPU Information ===${NC}"
    echo -n "CPU Usage: "
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    echo -e "${GREEN}$cpu_usage${NC}"
    echo -n "Load Average: "
    uptime | awk -F'load average:' '{print $2}'
    echo ""

    echo -e "${BLUE}=== Memory Information ===${NC}"
    free -h
    echo ""

    echo -e "${BLUE}=== Disk Usage ===${NC}"
    df -h | grep -E '^/dev/|Filesystem'
    echo ""

    echo -e "${BLUE}=== Top 5 Processes by Memory ===${NC}"
    ps aux --sort=-%mem | head -6
    echo ""

    read -p "Press Enter to continue..."
}

# Function to view service errors
view_service_errors() {
    print_header
    echo -e "${YELLOW}Recent Service Errors${NC}"
    echo ""

    for service in "${PROXMOX_SERVICES[@]}"; do
        echo -e "${BLUE}=== $service ===${NC}"
        if systemctl is-failed --quiet "$service"; then
            echo -e "Status: ${RED}FAILED${NC}"
            systemctl status "$service" --no-pager -l | tail -10
        else
            errors=$(journalctl -u "$service" -p err -n 5 --no-pager 2>/dev/null)
            if [ -n "$errors" ]; then
                echo "$errors"
            else
                echo -e "${GREEN}No recent errors${NC}"
            fi
        fi
        echo ""
    done

    read -p "Press Enter to continue..."
}

# Function to check cluster status
check_cluster_status() {
    print_header
    echo -e "${YELLOW}Cluster Status${NC}"
    echo ""

    if [ "$IS_CLUSTER" = false ]; then
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║     STANDALONE MODE DETECTED          ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}This node is running in standalone mode.${NC}"
        echo -e "No cluster configuration detected."
        echo ""
        echo -e "${BLUE}Node Information:${NC}"
        echo -e "  Node Name: ${GREEN}$NODE_NAME${NC}"
        echo -e "  Cluster Services: ${YELLOW}Not Applicable${NC}"
        echo ""
    else
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║       CLUSTER MODE DETECTED           ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        echo ""

        if command -v pvecm &> /dev/null; then
            echo -e "${BLUE}=== Cluster Information ===${NC}"
            pvecm status 2>/dev/null
            echo ""

            echo -e "${BLUE}=== Cluster Nodes ===${NC}"
            pvecm nodes 2>/dev/null
            echo ""
        else
            echo -e "${RED}pvecm command not found${NC}"
        fi

        echo -e "${BLUE}=== Corosync Status ===${NC}"
        systemctl status corosync --no-pager | head -15
        echo ""
    fi

    read -p "Press Enter to continue..."
}

# Function to check storage status
check_storage_status() {
    print_header
    echo -e "${YELLOW}Storage Status${NC}"
    echo ""

    if [ "$IS_CLUSTER" = true ]; then
        echo -e "${CYAN}Mode: Cluster - Showing all cluster storages${NC}"
        echo ""
    else
        echo -e "${CYAN}Mode: Standalone - Showing local storages only${NC}"
        echo ""
    fi

    if command -v pvesm &> /dev/null; then
        echo -e "${BLUE}=== Proxmox Storage Status ===${NC}"
        pvesm status
        echo ""

        if [ "$IS_CLUSTER" = true ]; then
            echo -e "${BLUE}=== Shared Storage (Cluster) ===${NC}"
            pvesm status | grep -E "active|shared" | grep "yes" || echo "No shared storage configured"
            echo ""
        fi
    else
        echo -e "${RED}pvesm command not found${NC}"
    fi

    echo -e "${BLUE}=== ZFS Pools (if available) ===${NC}"
    if command -v zpool &> /dev/null; then
        zpool_output=$(zpool list 2>/dev/null)
        if [ -n "$zpool_output" ]; then
            echo "$zpool_output"
            echo ""
            echo -e "${BLUE}=== ZFS Pool Health ===${NC}"
            zpool status 2>/dev/null
        else
            echo "No ZFS pools found"
        fi
    else
        echo "ZFS not installed"
    fi
    echo ""

    echo -e "${BLUE}=== LVM Information ===${NC}"
    pvs_output=$(pvs 2>/dev/null)
    if [ -n "$pvs_output" ]; then
        echo "Physical Volumes:"
        echo "$pvs_output"
    else
        echo "No LVM physical volumes found"
    fi
    echo ""

    vgs_output=$(vgs 2>/dev/null)
    if [ -n "$vgs_output" ]; then
        echo "Volume Groups:"
        echo "$vgs_output"
    else
        echo "No LVM volume groups found"
    fi
    echo ""

    echo -e "${BLUE}=== Local Disk Usage ===${NC}"
    df -h | grep -E '^/dev/|Filesystem'
    echo ""

    read -p "Press Enter to continue..."
}

# Function to check network connectivity
check_network() {
    print_header
    echo -e "${YELLOW}Network Connectivity Check${NC}"
    echo ""

    echo -e "${BLUE}=== Network Interfaces ===${NC}"
    ip -brief addr
    echo ""

    echo -e "${BLUE}=== Bridge Information ===${NC}"
    ip -brief link show type bridge
    echo ""

    echo -e "${BLUE}=== Network Connectivity Tests ===${NC}"
    echo -n "Checking DNS (8.8.8.8): "
    if ping -c 2 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi

    echo -n "Checking Internet (google.com): "
    if ping -c 2 google.com &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    echo ""

    echo -e "${BLUE}=== Listening Ports ===${NC}"
    ss -tlnp | grep -E 'pve|corosync' || echo "No Proxmox services listening"
    echo ""

    read -p "Press Enter to continue..."
}

# Function to view system logs
view_system_logs() {
    print_header
    echo -e "${YELLOW}System Logs (Last 50 lines)${NC}"
    echo ""

    echo -e "${BLUE}=== Syslog ===${NC}"
    tail -50 /var/log/syslog 2>/dev/null || journalctl -n 50 --no-pager
    echo ""

    read -p "Press Enter to continue..."
}

# Function to check Proxmox version
check_proxmox_version() {
    print_header
    echo -e "${YELLOW}Proxmox Version Information${NC}"
    echo ""

    if command -v pveversion &> /dev/null; then
        pveversion -v
    else
        echo -e "${RED}pveversion command not found${NC}"
        echo ""
        cat /etc/pve/.version 2>/dev/null || echo "Version file not found"
    fi
    echo ""

    echo -e "${BLUE}=== Kernel Version ===${NC}"
    uname -a
    echo ""

    read -p "Press Enter to continue..."
}

# Function to test cluster quorum
test_cluster_quorum() {
    print_header
    echo -e "${YELLOW}Cluster Quorum Test${NC}"
    echo ""

    if [ "$IS_CLUSTER" = false ]; then
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║     STANDALONE MODE DETECTED          ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Quorum is not applicable in standalone mode.${NC}"
        echo -e "This feature is only available when the node is part of a cluster."
        echo ""
    else
        if command -v pvecm &> /dev/null; then
            echo -e "${BLUE}=== Quorum Status ===${NC}"
            quorum_info=$(pvecm status | grep -i quorum)
            echo "$quorum_info"

            # Check if quorate
            if echo "$quorum_info" | grep -q "Quorate.*Yes"; then
                echo -e "${GREEN}✓ Cluster has quorum${NC}"
            else
                echo -e "${RED}✗ Cluster does NOT have quorum - CRITICAL!${NC}"
            fi
            echo ""

            echo -e "${BLUE}=== Expected Votes ===${NC}"
            pvecm status | grep -i votes
            echo ""

            echo -e "${BLUE}=== Cluster Members ===${NC}"
            pvecm status | grep -A 20 "Membership information"
            echo ""
        else
            echo -e "${RED}pvecm command not found${NC}"
        fi
    fi

    read -p "Press Enter to continue..."
}

# Function to check failed services
check_failed_services() {
    print_header
    echo -e "${YELLOW}Checking for Failed Services${NC}"
    echo ""

    echo -e "${BLUE}=== System-wide Failed Services ===${NC}"
    failed_services=$(systemctl --failed --no-pager --no-legend)
    if [ -z "$failed_services" ]; then
        echo -e "${GREEN}No failed services found${NC}"
    else
        systemctl --failed --no-pager
    fi
    echo ""

    echo -e "${BLUE}=== Proxmox Service Status ===${NC}"
    for service in "${PROXMOX_SERVICES[@]}"; do
        if systemctl is-failed --quiet "$service"; then
            echo -e "${RED}✗ $service: FAILED${NC}"
        elif systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}✓ $service: ACTIVE${NC}"
        else
            echo -e "${YELLOW}○ $service: INACTIVE${NC}"
        fi
    done
    echo ""

    read -p "Press Enter to continue..."
}

# Function to view journal for services
view_service_journal() {
    print_header
    echo -e "${YELLOW}Service Journal Logs${NC}"
    echo ""
    echo "Select service to view logs:"
    echo ""

    echo -e "${BLUE}=== Base Services ===${NC}"
    local counter=1
    for i in "${!BASE_SERVICES[@]}"; do
        echo "$counter. ${BASE_SERVICES[$i]}"
        ((counter++))
    done

    if [ "$IS_CLUSTER" = true ]; then
        echo ""
        echo -e "${BLUE}=== Cluster Services ===${NC}"
        for i in "${!CLUSTER_SERVICES[@]}"; do
            echo "$counter. ${CLUSTER_SERVICES[$i]}"
            ((counter++))
        done
    fi

    echo ""
    echo "0. Back"
    echo ""
    read -p "Select service: " service_num

    if [ "$service_num" = "0" ]; then
        return
    fi

    local selected_service=""

    # Determine which service was selected
    if [ "$service_num" -ge 1 ] && [ "$service_num" -le "${#BASE_SERVICES[@]}" ]; then
        selected_service="${BASE_SERVICES[$((service_num-1))]}"
    elif [ "$IS_CLUSTER" = true ] && [ "$service_num" -gt "${#BASE_SERVICES[@]}" ] && [ "$service_num" -lt "$counter" ]; then
        cluster_idx=$((service_num - ${#BASE_SERVICES[@]} - 1))
        selected_service="${CLUSTER_SERVICES[$cluster_idx]}"
    fi

    if [ -n "$selected_service" ]; then
        print_header
        echo -e "${YELLOW}Journal for $selected_service (Last 100 lines)${NC}"
        echo ""
        journalctl -u "$selected_service" -n 100 --no-pager
        echo ""
        read -p "Press Enter to continue..."
    else
        echo -e "${RED}Invalid selection${NC}"
        sleep 1
    fi
}

# Function to check VM/Container status
check_vm_container_status() {
    print_header
    echo -e "${YELLOW}VM and Container Status${NC}"
    echo ""

    if [ "$IS_CLUSTER" = true ]; then
        echo -e "${CYAN}Mode: Cluster - Showing VMs/Containers across all nodes${NC}"
        echo ""

        # Show cluster-wide resources
        if command -v pvesh &> /dev/null; then
            echo -e "${BLUE}=== Cluster Resources ===${NC}"
            pvesh get /cluster/resources --type vm 2>/dev/null | head -50 || echo "Unable to fetch cluster resources"
            echo ""
        fi
    else
        echo -e "${CYAN}Mode: Standalone - Showing local VMs/Containers only${NC}"
        echo ""
    fi

    if command -v qm &> /dev/null; then
        if [ "$IS_CLUSTER" = true ]; then
            echo -e "${BLUE}=== Virtual Machines (This Node: $NODE_NAME) ===${NC}"
        else
            echo -e "${BLUE}=== Virtual Machines ===${NC}"
        fi

        vm_list=$(qm list 2>/dev/null)
        if [ -n "$vm_list" ]; then
            echo "$vm_list"
            echo ""

            # Count VMs
            vm_count=$(echo "$vm_list" | tail -n +2 | wc -l)
            echo -e "${GREEN}Total VMs on this node: $vm_count${NC}"
        else
            echo "No VMs found"
        fi
        echo ""
    fi

    if command -v pct &> /dev/null; then
        if [ "$IS_CLUSTER" = true ]; then
            echo -e "${BLUE}=== Containers (This Node: $NODE_NAME) ===${NC}"
        else
            echo -e "${BLUE}=== Containers ===${NC}"
        fi

        ct_list=$(pct list 2>/dev/null)
        if [ -n "$ct_list" ]; then
            echo "$ct_list"
            echo ""

            # Count containers
            ct_count=$(echo "$ct_list" | tail -n +2 | wc -l)
            echo -e "${GREEN}Total Containers on this node: $ct_count${NC}"
        else
            echo "No containers found"
        fi
        echo ""
    fi

    read -p "Press Enter to continue..."
}

# Function to generate diagnostic report
generate_diagnostic_report() {
    print_header
    echo -e "${YELLOW}Generating Diagnostic Report${NC}"
    echo ""

    report_file="/tmp/proxmox-diagnostic-$(date +%Y%m%d-%H%M%S).txt"

    echo "Generating comprehensive diagnostic report..."
    echo "This may take a moment..."
    echo ""

    {
        echo "========================================="
        echo "Proxmox Diagnostic Report"
        echo "Generated: $(date)"
        echo "Node: $NODE_NAME"
        if [ "$IS_CLUSTER" = true ]; then
            echo "Mode: CLUSTER"
            echo "Cluster Name: $CLUSTER_NAME"
        else
            echo "Mode: STANDALONE"
        fi
        echo "========================================="
        echo ""

        echo "=== SYSTEM INFORMATION ==="
        uname -a
        echo ""

        echo "=== PROXMOX VERSION ==="
        pveversion -v 2>/dev/null || echo "Unable to get version"
        echo ""

        echo "=== BASE SERVICE STATUS ==="
        for service in "${BASE_SERVICES[@]}"; do
            echo "--- $service ---"
            systemctl status "$service" --no-pager
            echo ""
        done

        if [ "$IS_CLUSTER" = true ]; then
            echo "=== CLUSTER SERVICE STATUS ==="
            for service in "${CLUSTER_SERVICES[@]}"; do
                echo "--- $service ---"
                systemctl status "$service" --no-pager
                echo ""
            done
        fi

        echo "=== CLUSTER STATUS ==="
        if [ "$IS_CLUSTER" = true ]; then
            pvecm status 2>/dev/null || echo "Unable to get cluster status"
        else
            echo "Not in cluster mode - Standalone node"
        fi
        echo ""

        echo "=== STORAGE STATUS ==="
        pvesm status 2>/dev/null || echo "Unable to get storage status"
        echo ""

        if [ "$IS_CLUSTER" = true ]; then
            echo "=== VM/CONTAINER STATUS (Cluster-wide) ==="
            pvesh get /cluster/resources --type vm 2>/dev/null || echo "Unable to get cluster resources"
            echo ""
        fi

        echo "=== VM/CONTAINER STATUS (This Node) ==="
        echo "VMs:"
        qm list 2>/dev/null || echo "No VMs or unable to query"
        echo ""
        echo "Containers:"
        pct list 2>/dev/null || echo "No containers or unable to query"
        echo ""

        echo "=== NETWORK INTERFACES ==="
        ip addr
        echo ""

        echo "=== DISK USAGE ==="
        df -h
        echo ""

        echo "=== MEMORY USAGE ==="
        free -h
        echo ""

        echo "=== FAILED SERVICES ==="
        systemctl --failed --no-pager
        echo ""

        echo "=== RECENT ERRORS ==="
        journalctl -p err -n 50 --no-pager
        echo ""

    } > "$report_file"

    echo -e "${GREEN}Report generated successfully!${NC}"
    echo -e "Location: ${BLUE}$report_file${NC}"
    echo ""
    echo "You can view it with: cat $report_file"
    echo "Or copy it: cp $report_file /path/to/destination"
    echo ""

    read -p "Press Enter to continue..."
}

#############################################
# VM TEMPLATE CREATOR SECTION
#############################################

# Global template variables
TEMPLATE_DIR="/var/lib/vz/template/iso"
TEMPLATE_DOWNLOAD_DIR="$(pwd)/proxmox-templates"

# Function to ensure required packages are installed
check_template_requirements() {
    local missing_packages=()

    # Check for required commands
    command -v wget &>/dev/null || missing_packages+=("wget")
    command -v libguestfs-tools &>/dev/null || missing_packages+=("libguestfs-tools")

    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing required packages: ${missing_packages[*]}${NC}"
        apt-get update -qq
        apt-get install -y "${missing_packages[@]}"
        echo ""
    fi
}

# Function to get next available VM ID
get_next_vmid() {
    local vmid=9000
    while qm status "$vmid" &>/dev/null; do
        ((vmid++))
    done
    echo "$vmid"
}

# Function to download distro images
download_distro_image() {
    local distro=$1
    local url=""
    local filename=""

    mkdir -p "$TEMPLATE_DOWNLOAD_DIR"

    case $distro in
        "ubuntu-22.04")
            filename="ubuntu-22.04-cloudimg-amd64.img"
            url="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
            ;;
        "ubuntu-20.04")
            filename="ubuntu-20.04-cloudimg-amd64.img"
            url="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
            ;;
        "ubuntu-24.04")
            filename="ubuntu-24.04-cloudimg-amd64.img"
            url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
            ;;
        "debian-12")
            filename="debian-12-generic-amd64.qcow2"
            url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
            ;;
        "debian-11")
            filename="debian-11-generic-amd64.qcow2"
            url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
            ;;
        "almalinux-9")
            filename="AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            url="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            ;;
        "almalinux-8")
            filename="AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            url="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            ;;
        "rocky-9")
            filename="Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
            url="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
            ;;
        "rocky-8")
            filename="Rocky-8-GenericCloud-Base.latest.x86_64.qcow2"
            url="https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2"
            ;;
        "centos-stream-9")
            filename="CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            url="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            ;;
        "fedora-39")
            filename="Fedora-Cloud-Base-39-latest.x86_64.qcow2"
            url="https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2"
            ;;
        *)
            echo -e "${RED}Unknown distro: $distro${NC}"
            return 1
            ;;
    esac

    local dest_file="$TEMPLATE_DOWNLOAD_DIR/$filename"

    # Check if file already exists
    if [ -f "$dest_file" ]; then
        echo -e "${YELLOW}Image already downloaded: $filename${NC}" >&2
        read -p "Re-download? (y/n): " redownload >&2
        if [ "$redownload" != "y" ]; then
            echo "$dest_file"
            return 0
        fi
    fi

    echo -e "${CYAN}Downloading $filename...${NC}" >&2
    echo -e "${BLUE}URL: $url${NC}" >&2
    echo "" >&2

    # Download with better error handling
    wget --show-progress -O "$dest_file" "$url" 2>&1 >&2
    local wget_status=$?

    if [ $wget_status -eq 0 ]; then
        # Verify file exists and has content
        if [ -f "$dest_file" ] && [ -s "$dest_file" ]; then
            local file_size=$(stat -f%z "$dest_file" 2>/dev/null || stat -c%s "$dest_file" 2>/dev/null)
            echo "" >&2
            echo -e "${GREEN}✓ Download completed!${NC}" >&2
            echo -e "${CYAN}File: $dest_file${NC}" >&2
            echo -e "${CYAN}Size: $(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "$file_size bytes")${NC}" >&2
            echo "" >&2

            # Make sure file is readable
            chmod 644 "$dest_file"

            # Output only the file path to stdout for capture
            echo "$dest_file"
            return 0
        else
            echo -e "${RED}✗ Download failed - file is empty or missing${NC}" >&2
            rm -f "$dest_file"
            return 1
        fi
    else
        echo -e "${RED}✗ Download failed!${NC}" >&2
        rm -f "$dest_file"
        return 1
    fi
}

# Function to get template configuration from user
get_template_config() {
    print_header
    echo -e "${YELLOW}Step 2: Template Configuration${NC}"
    echo ""

    # VM ID
    local default_vmid=$(get_next_vmid)
    read -p "Enter VM ID [$default_vmid]: " vmid
    vmid=${vmid:-$default_vmid}

    # Template name
    read -p "Enter template name [template-${distro}]: " template_name
    template_name=${template_name:-template-${distro}}

    # CPU cores
    read -p "Enter number of CPU cores [2]: " cpu_cores
    cpu_cores=${cpu_cores:-2}

    # Memory (MB)
    read -p "Enter memory size in MB [2048]: " memory
    memory=${memory:-2048}

    # Disk size
    read -p "Enter disk size (e.g., 20G) [20G]: " disk_size
    disk_size=${disk_size:-20G}

    # Storage location
    read -p "Enter storage location [local-lvm]: " storage
    storage=${storage:-local-lvm}

    # Network bridge
    read -p "Enter network bridge [vmbr0]: " bridge
    bridge=${bridge:-vmbr0}

    # SSH Port
    read -p "Enter SSH port [22]: " ssh_port
    ssh_port=${ssh_port:-22}

    # Root password
    read -sp "Enter root password: " root_password
    echo ""
    read -sp "Confirm root password: " root_password_confirm
    echo ""

    if [ "$root_password" != "$root_password_confirm" ]; then
        echo -e "${RED}Passwords do not match!${NC}"
        sleep 2
        return 1
    fi

    # Enable root login
    read -p "Enable root login with password? (y/n) [y]: " enable_root
    enable_root=${enable_root:-y}

    # Install qemu-guest-agent
    read -p "Install qemu-guest-agent? (y/n) [y]: " install_agent
    install_agent=${install_agent:-y}

    # Export variables
    export TMPL_VMID="$vmid"
    export TMPL_NAME="$template_name"
    export TMPL_CPU="$cpu_cores"
    export TMPL_MEMORY="$memory"
    export TMPL_DISK_SIZE="$disk_size"
    export TMPL_STORAGE="$storage"
    export TMPL_BRIDGE="$bridge"
    export TMPL_SSH_PORT="$ssh_port"
    export TMPL_ROOT_PASSWORD="$root_password"
    export TMPL_ENABLE_ROOT="$enable_root"
    export TMPL_INSTALL_AGENT="$install_agent"

    return 0
}

# Function to create VM from cloud image
create_vm_from_image() {
    local image_file=$1
    local vmid=$2
    local name=$3

    echo -e "${CYAN}Creating VM ${vmid} - ${name}${NC}"
    echo ""

    # Verify image file exists and is accessible
    if [ ! -f "$image_file" ]; then
        echo -e "${RED}✗ Image file not found: $image_file${NC}"
        return 1
    fi

    if [ ! -r "$image_file" ]; then
        echo -e "${RED}✗ Image file not readable: $image_file${NC}"
        echo -e "${YELLOW}Attempting to fix permissions...${NC}"
        chmod 644 "$image_file"
    fi

    local file_size=$(stat -f%z "$image_file" 2>/dev/null || stat -c%s "$image_file" 2>/dev/null)
    echo -e "${CYAN}Image file: $image_file${NC}"
    echo -e "${CYAN}Size: $(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "$file_size bytes")${NC}"
    echo ""

    # Create VM
    echo "Creating VM..."
    qm create "$vmid" \
        --name "$name" \
        --memory "$TMPL_MEMORY" \
        --cores "$TMPL_CPU" \
        --net0 "virtio,bridge=$TMPL_BRIDGE" \
        --scsihw virtio-scsi-pci

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to create VM${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ VM created${NC}"
    echo ""

    # Import disk
    echo "Importing disk image..."
    echo -e "${YELLOW}This may take a few minutes depending on image size...${NC}"

    qm importdisk "$vmid" "$image_file" "$TMPL_STORAGE"

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to import disk${NC}"
        echo -e "${YELLOW}Cleaning up VM...${NC}"
        qm destroy "$vmid" 2>/dev/null
        return 1
    fi

    echo -e "${GREEN}✓ Disk imported${NC}"

    # Attach disk
    echo "Attaching disk to VM..."
    qm set "$vmid" --scsi0 "${TMPL_STORAGE}:vm-${vmid}-disk-0"
    qm set "$vmid" --boot order=scsi0
    qm set "$vmid" --ide2 "${TMPL_STORAGE}:cloudinit"

    # Add serial console
    qm set "$vmid" --serial0 socket --vga serial0

    # Enable QEMU guest agent
    qm set "$vmid" --agent enabled=1

    echo -e "${GREEN}✓ VM configuration completed${NC}"

    return 0
}

# Function to customize VM
customize_vm() {
    local vmid=$1
    local distro=$2

    echo -e "${CYAN}Applying customizations...${NC}"
    echo "This may take a few minutes..."
    echo ""

    # Detect package manager based on distro
    local pkg_manager=""
    local agent_package="qemu-guest-agent"

    if [[ "$distro" =~ ubuntu|debian ]]; then
        pkg_manager="apt-get"
    elif [[ "$distro" =~ alma|rocky|centos|fedora ]]; then
        pkg_manager="dnf"
    fi

    # Create cloud-init user-data configuration
    local cloudinit_file="/tmp/user-data-${vmid}.yml"

    cat > "$cloudinit_file" <<EOF
#cloud-config
hostname: ${TMPL_NAME}
manage_etc_hosts: true

users:
  - name: root
    lock_passwd: false
    shell: /bin/bash

chpasswd:
  list: |
    root:${TMPL_ROOT_PASSWORD}
  expire: False

ssh_pwauth: true
disable_root: false

runcmd:
  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
EOF

    # Add SSH port configuration if not default
    if [ "$TMPL_SSH_PORT" != "22" ]; then
        cat >> "$cloudinit_file" <<EOF
  - sed -i 's/^#*Port.*/Port ${TMPL_SSH_PORT}/' /etc/ssh/sshd_config
EOF
    fi

    # Add qemu-guest-agent installation if requested
    if [ "$TMPL_INSTALL_AGENT" = "y" ]; then
        if [[ "$distro" =~ ubuntu|debian ]]; then
            cat >> "$cloudinit_file" <<EOF
  - apt-get update
  - DEBIAN_FRONTEND=noninteractive apt-get install -y qemu-guest-agent
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
EOF
        else
            cat >> "$cloudinit_file" <<EOF
  - ${pkg_manager} install -y qemu-guest-agent
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
EOF
        fi
    fi

    # Restart SSH to apply changes
    cat >> "$cloudinit_file" <<EOF
  - systemctl restart sshd || systemctl restart ssh

package_update: true
package_upgrade: false

power_state:
  mode: reboot
  timeout: 300
  condition: True
EOF

    echo -e "${CYAN}Configuring cloud-init with custom settings...${NC}"

    # Apply cloud-init configuration
    qm set "$vmid" --ciuser root
    qm set "$vmid" --cipassword "$TMPL_ROOT_PASSWORD"
    qm set "$vmid" --ipconfig0 ip=dhcp
    qm set "$vmid" --cicustom "user=local:snippets/user-data-${vmid}.yml"

    # Copy cloud-init file to Proxmox snippets directory
    local snippets_dir="/var/lib/vz/snippets"
    if [ ! -d "$snippets_dir" ]; then
        mkdir -p "$snippets_dir"
    fi

    cp "$cloudinit_file" "${snippets_dir}/user-data-${vmid}.yml"

    # Cleanup temp file
    rm -f "$cloudinit_file"

    echo ""
    echo -e "${GREEN}✓ Cloud-init configuration applied${NC}"
    echo ""
    echo -e "${BLUE}Configuration Summary:${NC}"
    echo -e "  • Root password: ${GREEN}Set${NC}"
    echo -e "  • Root login: ${GREEN}Enabled${NC}"
    echo -e "  • SSH port: ${CYAN}${TMPL_SSH_PORT}${NC}"
    if [ "$TMPL_INSTALL_AGENT" = "y" ]; then
        echo -e "  • QEMU Guest Agent: ${GREEN}Will be installed on first boot${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Note: Changes will be applied on first VM boot${NC}"
    echo -e "${YELLOW}The VM will automatically reboot after configuration${NC}"
    echo ""

    read -p "Press Enter to continue..."
}

# Function to convert VM to template
convert_to_template() {
    local vmid=$1

    read -p "Convert this VM to a template? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        echo "Converting to template..."
        qm template "$vmid"

        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}════════════════════════════════════════${NC}"
            echo -e "${GREEN}✓ Template created successfully!${NC}"
            echo -e "${GREEN}════════════════════════════════════════${NC}"
            echo ""
            echo -e "Template ID: ${CYAN}${vmid}${NC}"
            echo -e "Template Name: ${CYAN}${TMPL_NAME}${NC}"
            echo ""
            echo -e "${BLUE}To clone this template:${NC}"
            echo -e "  qm clone ${vmid} <new-vmid> --name <new-name> --full"
            echo ""
            echo -e "${BLUE}SSH Configuration:${NC}"
            echo -e "  Port: ${CYAN}${TMPL_SSH_PORT}${NC}"
            echo -e "  Root Login: ${CYAN}${TMPL_ENABLE_ROOT}${NC}"
            echo ""
        else
            echo -e "${RED}Failed to convert to template${NC}"
        fi
    else
        echo -e "${YELLOW}Template conversion cancelled${NC}"
        echo "VM ${vmid} remains as a regular VM"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Main template creation workflow
create_template_workflow() {
    local distro=$1

    # Check requirements
    check_template_requirements

    # Download image
    print_header
    echo -e "${YELLOW}Step 1: Downloading ${distro} Image${NC}"
    echo ""

    local image_file=$(download_distro_image "$distro")
    local download_status=$?

    if [ $download_status -ne 0 ] || [ -z "$image_file" ]; then
        echo ""
        echo -e "${RED}✗ Failed to download image${NC}"
        echo -e "${YELLOW}Please check your internet connection and try again${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    # Verify the downloaded file exists before proceeding
    if [ ! -f "$image_file" ]; then
        echo ""
        echo -e "${RED}✗ Downloaded file not found: $image_file${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    echo -e "${GREEN}✓ Image ready for template creation${NC}"
    echo ""
    echo -e "${CYAN}Proceeding to configuration...${NC}"
    sleep 2

    # Get configuration
    if ! get_template_config; then
        return 1
    fi

    # Show configuration summary
    print_header
    echo -e "${YELLOW}Step 3: Configuration Summary${NC}"
    echo ""
    echo -e "VM ID: ${CYAN}${TMPL_VMID}${NC}"
    echo -e "Name: ${CYAN}${TMPL_NAME}${NC}"
    echo -e "CPU Cores: ${CYAN}${TMPL_CPU}${NC}"
    echo -e "Memory: ${CYAN}${TMPL_MEMORY}MB${NC}"
    echo -e "Disk Size: ${CYAN}${TMPL_DISK_SIZE}${NC}"
    echo -e "Storage: ${CYAN}${TMPL_STORAGE}${NC}"
    echo -e "Network Bridge: ${CYAN}${TMPL_BRIDGE}${NC}"
    echo -e "SSH Port: ${CYAN}${TMPL_SSH_PORT}${NC}"
    echo -e "Root Login: ${CYAN}${TMPL_ENABLE_ROOT}${NC}"
    echo -e "Install QEMU Agent: ${CYAN}${TMPL_INSTALL_AGENT}${NC}"
    echo ""

    read -p "Proceed with template creation? (yes/no): " proceed

    if [ "$proceed" != "yes" ]; then
        echo -e "${YELLOW}Template creation cancelled${NC}"
        read -p "Press Enter to continue..."
        return 0
    fi

    # Create VM from image
    print_header
    echo -e "${YELLOW}Step 4: Creating VM from Image${NC}"
    echo ""

    if ! create_vm_from_image "$image_file" "$TMPL_VMID" "$TMPL_NAME"; then
        echo -e "${RED}Failed to create VM from image${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    echo ""
    read -p "Press Enter to continue to customization..."

    # Customize VM
    print_header
    echo -e "${YELLOW}Step 5: Customizing VM ${TMPL_VMID}${NC}"
    echo ""
    customize_vm "$TMPL_VMID" "$distro"

    # Convert to template
    print_header
    echo -e "${YELLOW}Step 6: Converting to Template${NC}"
    echo ""
    convert_to_template "$TMPL_VMID"
}

# Template creator menu
template_creator_menu() {
    while true; do
        print_header
        echo -e "${YELLOW}VM Template Creator${NC}"
        echo ""
        echo -e "${BLUE}Select a distribution to create a template:${NC}"
        echo ""
        echo -e "${CYAN}=== Ubuntu ===${NC}"
        echo "1.  Ubuntu 24.04 LTS (Noble)"
        echo "2.  Ubuntu 22.04 LTS (Jammy)"
        echo "3.  Ubuntu 20.04 LTS (Focal)"
        echo ""
        echo -e "${CYAN}=== Debian ===${NC}"
        echo "4.  Debian 12 (Bookworm)"
        echo "5.  Debian 11 (Bullseye)"
        echo ""
        echo -e "${CYAN}=== Enterprise Linux ===${NC}"
        echo "6.  AlmaLinux 9"
        echo "7.  AlmaLinux 8"
        echo "8.  Rocky Linux 9"
        echo "9.  Rocky Linux 8"
        echo "10. CentOS Stream 9"
        echo ""
        echo -e "${CYAN}=== Fedora ===${NC}"
        echo "11. Fedora 39"
        echo ""
        echo "0.  Back to main menu"
        echo ""
        read -p "Select option: " distro_choice

        case $distro_choice in
            1)
                create_template_workflow "ubuntu-24.04"
                ;;
            2)
                create_template_workflow "ubuntu-22.04"
                ;;
            3)
                create_template_workflow "ubuntu-20.04"
                ;;
            4)
                create_template_workflow "debian-12"
                ;;
            5)
                create_template_workflow "debian-11"
                ;;
            6)
                create_template_workflow "almalinux-9"
                ;;
            7)
                create_template_workflow "almalinux-8"
                ;;
            8)
                create_template_workflow "rocky-9"
                ;;
            9)
                create_template_workflow "rocky-8"
                ;;
            10)
                create_template_workflow "centos-stream-9"
                ;;
            11)
                create_template_workflow "fedora-39"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main menu
main_menu() {
    while true; do
        print_header
        echo "1. Troubleshooting & Diagnostics"
        echo "2. VM Template Creator"
        echo "0. Exit"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1)
                troubleshooting_menu
                ;;
            2)
                template_creator_menu
                ;;
            0)
                print_header
                echo -e "${GREEN}Thank you for using Proxmox Master Script!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main execution
check_root
detect_cluster
main_menu
