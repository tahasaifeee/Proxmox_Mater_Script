# Proxmox Master Management Script

A comprehensive one-click bash script for managing and troubleshooting Proxmox VE servers with **intelligent cluster detection**.

## Key Features

⚡ **Automatic Cluster Detection** - Automatically detects if the node is standalone or part of a cluster
🎯 **Context-Aware Operations** - Adjusts all operations based on cluster/standalone mode
🔧 **Service Management** - Separate handling of base and cluster-specific services
📊 **Comprehensive Diagnostics** - Full system health checks and reporting
🎨 **User-Friendly Interface** - Color-coded, menu-driven interface with clear status indicators
🚀 **VM Template Creator** - Automated creation of VM templates from official cloud images

## How It Works

The script automatically detects whether your Proxmox node is:
- **Standalone Mode**: Single node, manages only base Proxmox services
- **Cluster Mode**: Part of a cluster, manages both base and cluster services

All features adapt to the detected mode, showing only relevant information and managing appropriate services.

### Menu Structure

```
Main Menu
├── 1. Troubleshooting & Diagnostics
│   │
│   ├── Service Management
│   │   ├── 1. Check all services status
│   │   ├── 2. Start all services
│   │   ├── 3. Stop all services
│   │   ├── 4. Restart all services
│   │   ├── 5. Manage individual service
│   │   └── 6. Manage services at boot
│   │
│   └── System Diagnostics
│       ├── 7.  System resource check (CPU/RAM/Disk)
│       ├── 8.  View recent service errors
│       ├── 9.  Check cluster status
│       ├── 10. Check storage status
│       ├── 11. Check network connectivity
│       ├── 12. View system logs (last 50 lines)
│       ├── 13. Check Proxmox version
│       ├── 14. Test cluster quorum
│       ├── 15. Check failed services
│       ├── 16. View journal for Proxmox services
│       ├── 17. Check VM/Container status
│       └── 18. Generate full diagnostic report
│
└── 2. VM Template Creator
    ├── Ubuntu (24.04, 22.04, 20.04 LTS)
    ├── Debian (12 Bookworm, 11 Bullseye)
    ├── AlmaLinux (9, 8)
    ├── Rocky Linux (9, 8)
    ├── CentOS Stream 9
    └── Fedora 39
```

## Managed Services

The script intelligently manages services based on your node configuration:

### Base Services (Always Managed)
- **pvedaemon** - Proxmox VE API daemon
- **pveproxy** - Proxmox VE web interface proxy
- **pvestatd** - Proxmox VE statistics daemon
- **pve-firewall** - Proxmox firewall service

### Cluster Services (Only in Cluster Mode)
- **pve-cluster** - Proxmox cluster service
- **pve-ha-lrm** - High Availability Local Resource Manager
- **pve-ha-crm** - High Availability Cluster Resource Manager
- **corosync** - Cluster communication service

The script automatically detects cluster configuration and only manages cluster services when appropriate.

## Quick Start (One-Command Installation)

Run this single command on your Proxmox server to download and execute the script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tahasaifeee/Proxmox_Mater_Script/main/proxmox-master.sh)"
```

**Alternative methods:**

Using wget:
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/tahasaifeee/Proxmox_Mater_Script/main/proxmox-master.sh)"
```

If the main branch doesn't exist, try:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tahasaifeee/Proxmox_Mater_Script/master/proxmox-master.sh)"
```

**Direct raw link:**
```
https://raw.githubusercontent.com/tahasaifeee/Proxmox_Mater_Script/main/proxmox-master.sh
```

## Manual Installation

1. Copy the script to your Proxmox server:
   ```bash
   scp proxmox-master.sh root@your-proxmox-server:/root/
   ```

2. SSH into your Proxmox server:
   ```bash
   ssh root@your-proxmox-server
   ```

3. Make the script executable:
   ```bash
   chmod +x proxmox-master.sh
   ```

## Usage

Run the script as root:

```bash
sudo ./proxmox-master.sh
```

Or directly as root user:

```bash
./proxmox-master.sh
```

## VM Template Creator

The VM Template Creator is a powerful feature that automates the creation of standardized VM templates from official cloud images. This feature streamlines the process of setting up reusable templates for rapid VM deployment.

### Supported Distributions

#### Ubuntu
- **Ubuntu 24.04 LTS (Noble)** - Latest LTS release
- **Ubuntu 22.04 LTS (Jammy)** - Popular LTS release
- **Ubuntu 20.04 LTS (Focal)** - Stable LTS release

#### Debian
- **Debian 12 (Bookworm)** - Latest stable release
- **Debian 11 (Bullseye)** - Previous stable release

#### Enterprise Linux
- **AlmaLinux 9 & 8** - RHEL-compatible enterprise Linux
- **Rocky Linux 9 & 8** - Community-driven enterprise Linux
- **CentOS Stream 9** - Rolling-release RHEL preview

#### Fedora
- **Fedora 39** - Cutting-edge features and packages

### Template Features

#### Automated Download
- Downloads official cloud images from trusted sources
- Supports qcow2 and raw image formats
- Caches downloaded images to avoid re-downloading
- Progress indicators during download

#### Customizable Configuration
**VM Specifications:**
- VM ID (auto-detects next available ID starting from 9000)
- Template name
- CPU cores (default: 2)
- Memory in MB (default: 2048)
- Disk size (default: 20G, expandable)
- Storage location (default: local-lvm)
- Network bridge (default: vmbr0)

**Security Settings:**
- Custom SSH port (default: 22)
- Root password configuration
- Enable/disable root login with password
- Password authentication setup

**System Configuration:**
- QEMU Guest Agent installation (recommended)
- Cloud-init integration
- Automatic package updates during setup

#### Template Creation Workflow

1. **Select Distribution**: Choose from 11+ supported Linux distributions
2. **Download Image**: Automatically downloads official cloud image
3. **Configure Template**: Set VM specifications and security options
4. **Create VM**: Builds VM from cloud image with your specifications
5. **Customize**: Applies your security and configuration settings
6. **Convert to Template**: Finalizes as a reusable template

### Using Templates

Once created, templates can be cloned to create new VMs:

```bash
# Clone template to create a new VM
qm clone <template-id> <new-vmid> --name <vm-name> --full

# Example:
qm clone 9000 100 --name my-ubuntu-server --full
```

### Template Benefits

✅ **Consistency** - All VMs from the same template have identical configurations
✅ **Speed** - Deploy new VMs in seconds instead of installing from ISO
✅ **Standardization** - Enforce security policies and configurations
✅ **Efficiency** - Reduces manual configuration and human error
✅ **Flexibility** - Customize templates for different use cases
✅ **Best Practices** - Uses official cloud images optimized for virtualization

### Requirements

The script automatically installs required packages:
- `wget` - For downloading cloud images
- `libguestfs-tools` - For image customization (optional)

### Storage Considerations

**local-lvm**: Basic cloud-init configuration (SSH port changes require manual setup)
**Other storage types**: Full customization support with virt-customize

### Example Use Cases

1. **Development Environments**: Create templates with pre-configured dev tools
2. **Testing**: Quickly spin up clean test environments
3. **Production**: Standardized servers with security hardening
4. **Multi-tenant**: Separate templates for different customers or projects
5. **Disaster Recovery**: Ready-to-deploy templates for quick restoration

## Cluster-Aware Features

### Automatic Mode Detection

On startup, the script automatically detects:
1. Presence of cluster configuration files (`/etc/pve/corosync.conf`)
2. Cluster name (if in cluster mode)
3. Node name
4. Which services should be managed

### Visual Indicators

The script displays the current mode in the header of every screen:
- **Standalone Mode**: `Mode: Standalone | Node: hostname`
- **Cluster Mode**: `Mode: Cluster | Cluster Name: name | Node: hostname`

### Context-Aware Behavior

#### In Standalone Mode:
- ✓ Manages only base Proxmox services
- ✓ Shows local storage only
- ✓ Displays VMs/Containers on this node only
- ✓ Skips cluster-specific checks (quorum, cluster status)
- ✓ No warnings about cluster operations

#### In Cluster Mode:
- ✓ Manages both base and cluster services
- ✓ Shows shared and local storage
- ✓ Displays cluster-wide VM/Container overview + local details
- ✓ Includes cluster health checks (quorum, nodes, HA)
- ✓ Warnings before operations that affect cluster
- ✓ Shows cluster resource distribution

## Feature Details

### Service Management

#### Check All Services Status
- **Cluster-Aware**: Separates base and cluster services
- Displays real-time status of applicable services
- Color-coded output (Green = Active, Red = Inactive)
- Shows service categories (Base Services / Cluster Services)
- Quick overview of system health

#### Start All Services
- **Cluster-Aware**: Starts base services first, then cluster services
- Proper startup sequence for service dependencies
- Shows success/failure status for each service
- Useful for system recovery

#### Stop All Services
- **Cluster-Aware**: Extra warnings when stopping cluster services
- Alerts about potential impact on HA and cluster operations
- Includes confirmation prompt to prevent accidental shutdowns
- Stops services in reverse order for clean shutdown

#### Restart All Services
- Restarts all services to apply configuration changes
- Useful after updates or configuration modifications

#### Manage Individual Service
- Interactive menu to select specific service
- Actions available per service:
  - Start
  - Stop
  - Restart
  - View detailed status

#### Manage Services at Boot
- Enable all services to start at system boot
- Disable services from auto-starting
- View current boot configuration

### System Diagnostics

#### System Resource Check
- **CPU Usage**: Real-time CPU utilization percentage
- **Load Average**: System load over time
- **Memory**: RAM usage (total, used, free, available)
- **Disk Space**: All mounted filesystems usage
- **Top Processes**: 5 processes using most memory

#### View Recent Service Errors
- Scans journal logs for each Proxmox service
- Displays last 5 error entries per service
- Helps identify service-specific issues

#### Check Cluster Status
- **Cluster-Aware**: Shows different information based on mode
- **Standalone**: Displays message that cluster features are not applicable
- **Cluster**: Shows full cluster information, node list, corosync status
- Node list and their status
- Useful for cluster troubleshooting

#### Check Storage Status
- **Cluster-Aware**: Identifies shared vs local storage
- **Standalone**: Shows local storage only
- **Cluster**: Shows shared storage + local storage breakdown
- Proxmox storage backend status
- ZFS pool information (if configured)
- LVM physical volumes and volume groups
- Storage capacity and availability

#### Check Network Connectivity
- Network interfaces and IP addresses
- Bridge configurations
- DNS connectivity test (8.8.8.8)
- Internet connectivity test (google.com)
- Listening ports for Proxmox services

#### View System Logs
- Last 50 lines of system logs
- Quick access to recent system events
- Useful for general troubleshooting

#### Check Proxmox Version
- Proxmox VE version information
- All installed package versions
- Kernel version
- Helps verify system updates

#### Test Cluster Quorum
- **Cluster-Aware**: Only applicable in cluster mode
- **Standalone**: Shows informational message that quorum is not applicable
- **Cluster**: Full quorum status, vote information, member list
- Visual indicator if cluster has/lacks quorum
- Critical for cluster operation verification

#### Check Failed Services
- **Cluster-Aware**: Checks all applicable services
- System-wide failed services scan
- Separate status for base and cluster services
- Quick identification of problems

#### View Journal for Proxmox Services
- **Cluster-Aware**: Lists services by category
- Select individual service to view logs
- Last 100 journal entries
- Detailed troubleshooting information
- Organized by Base Services / Cluster Services

#### Check VM/Container Status
- **Cluster-Aware**: Shows different levels of detail
- **Standalone**: Local VMs/Containers only
- **Cluster**: Cluster-wide resources + local node breakdown
- VM and container counts
- Quick overview of hosted workloads across cluster

#### Generate Full Diagnostic Report
- **Cluster-Aware**: Includes mode-specific information
- Report header includes cluster name and mode
- Separate sections for base and cluster services
- **Standalone**: Local resource information only
- **Cluster**: Cluster-wide + local resource details
- Comprehensive system information
- All service statuses
- Cluster, storage, and network details
- Disk and memory usage
- Recent errors
- Saves to `/tmp/proxmox-diagnostic-TIMESTAMP.txt`
- Perfect for sharing with support teams

## Script Highlights

### User-Friendly Features
- ✅ Color-coded output for easy reading
- ✅ Clear section headers and organization
- ✅ Confirmation prompts for destructive operations
- ✅ "Press Enter to continue" pagination
- ✅ Input validation
- ✅ Descriptive error messages

### Safety Features
- ✅ Root permission verification
- ✅ Confirmation before stopping services
- ✅ Graceful error handling
- ✅ Non-destructive diagnostics
- ✅ Read-only system checks

### Technical Features
- ✅ Proper service start/stop ordering
- ✅ Comprehensive system checks
- ✅ Journal log integration
- ✅ Multi-service management
- ✅ Diagnostic report generation

## Usage Examples

### Example 1: Standalone Node

When running on a standalone Proxmox node:
```
================================================
     Proxmox Master Management Script
================================================
Mode: Standalone | Node: pve-node1
================================================

The script will:
- Manage only base services (pvedaemon, pveproxy, pvestatd, pve-firewall)
- Skip cluster service checks
- Show local storage and VMs only
- Display "Not applicable" for cluster features
```

### Example 2: Cluster Node

When running on a node that's part of a cluster:
```
================================================
     Proxmox Master Management Script
================================================
Mode: Cluster | Cluster Name: production-cluster
Node: pve-node1
================================================

The script will:
- Manage base + cluster services (adds pve-cluster, corosync, HA services)
- Show cluster health and quorum status
- Display shared storage and cluster-wide VMs
- Include warnings about cluster impact
- Show both cluster-wide and node-specific information
```

## Requirements

- Proxmox VE (any recent version)
- Root access
- Bash shell
- Systemd (standard on Proxmox)

## Troubleshooting the Script

If the script doesn't run:

1. Check permissions:
   ```bash
   ls -l proxmox-master.sh
   chmod +x proxmox-master.sh
   ```

2. Verify you're running as root:
   ```bash
   whoami
   ```

3. Check bash is available:
   ```bash
   which bash
   ```

## Use Cases

### Daily Operations
- Quick health check of all services
- Start services after maintenance
- Check system resources before deploying VMs

### Troubleshooting
- Identify which service is failing
- Review error logs for specific services
- Generate diagnostic report for support

### Maintenance
- Restart services after configuration changes
- Verify cluster status after node changes
- Check storage before expanding

### Monitoring
- Regular service status checks
- Resource utilization monitoring
- Network connectivity verification

### Template Management
- Create standardized VM templates for rapid deployment
- Build templates with pre-configured security settings
- Set up development/testing/production templates
- Maintain consistency across multiple VMs
- Quick recovery with ready-to-deploy templates

## Best Practices

1. **Regular Status Checks**: Run option 1 daily to ensure all services are running
2. **Before Updates**: Generate diagnostic report before major updates
3. **After Changes**: Restart services after configuration modifications
4. **Troubleshooting**: Use diagnostic report when opening support tickets
5. **Cluster Changes**: Always check quorum after node modifications

## Notes

- The script is non-destructive and safe to run
- Diagnostic reports are saved in `/tmp/` and can be safely deleted
- Service management requires root privileges
- Some features require cluster configuration (will show appropriate messages if not configured)

## License

This script is provided as-is for Proxmox VE server management.

## Support

For issues or questions:
1. Review the diagnostic report output
2. Check Proxmox VE documentation
3. Consult Proxmox community forums

---

## Changelog

### Version 3.0 - Template Creator Release
- ✨ **NEW**: VM Template Creator with multi-distro support
- ✨ **NEW**: Support for 11+ Linux distributions (Ubuntu, Debian, AlmaLinux, Rocky, CentOS, Fedora)
- ✨ **NEW**: Automated cloud image download from official sources
- ✨ **NEW**: Interactive template configuration (CPU, RAM, disk, network)
- ✨ **NEW**: Customizable SSH port and root login settings
- ✨ **NEW**: QEMU Guest Agent installation option
- ✨ **NEW**: Cloud-init integration for initial VM configuration
- ✨ **NEW**: Automatic VM ID detection starting from 9000
- ✨ **NEW**: Template conversion workflow with confirmation
- 🔧 **IMPROVED**: Enhanced cluster name detection with multiple fallback methods
- 🔧 **IMPROVED**: More robust error handling and user feedback

### Version 2.0 - Cluster-Aware Release
- ✨ **NEW**: Automatic cluster detection
- ✨ **NEW**: Intelligent service management (base vs cluster services)
- ✨ **NEW**: Context-aware operations for standalone/cluster modes
- ✨ **NEW**: Enhanced diagnostics with cluster-specific information
- ✨ **NEW**: Visual mode indicators in all screens
- ✨ **NEW**: Cluster quorum validation with visual indicators
- ✨ **NEW**: Separate handling of shared/local storage
- ✨ **NEW**: Cluster-wide VM/Container overview
- 🔧 **IMPROVED**: Better warnings for cluster-impacting operations
- 🔧 **IMPROVED**: Service organization and management
- 🔧 **IMPROVED**: Diagnostic report with mode-specific details

### Version 1.0 - Initial Release
- Basic service management
- System diagnostics
- Menu-driven interface

---

**Current Version**: 3.0 (Template Creator)
**Last Updated**: 2025
**Compatible with**: Proxmox VE 7.x and 8.x (Standalone and Cluster)
