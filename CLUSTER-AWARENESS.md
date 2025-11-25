# Cluster-Aware Features Guide

## Overview

The Proxmox Master Script v2.0 automatically adapts its behavior based on whether your node is standalone or part of a cluster. This document explains how the detection works and what changes based on the mode.

## How Cluster Detection Works

### Detection Method

The script checks for the presence of cluster configuration files:
- `/etc/pve/corosync.conf`
- `/etc/corosync/corosync.conf`

If both files exist, the node is considered part of a cluster.

### Information Gathered

When cluster mode is detected, the script also retrieves:
- Cluster name (via `pvecm status`)
- Node name (via `hostname`)
- Cluster member list
- Quorum status

## Service Management Differences

### Base Services (Always Managed)

These services are managed regardless of cluster status:
- `pvedaemon` - Core Proxmox API daemon
- `pveproxy` - Web interface proxy
- `pvestatd` - Statistics collection daemon
- `pve-firewall` - Firewall service

### Cluster Services (Only in Cluster Mode)

These services are ONLY managed when cluster is detected:
- `pve-cluster` - Cluster configuration and management
- `pve-ha-lrm` - Local Resource Manager for HA
- `pve-ha-crm` - Cluster Resource Manager for HA
- `corosync` - Cluster communication layer

## Feature Behavior Comparison

### 1. Check All Services Status

#### Standalone Mode
```
=== Base Services ===
✓ pvedaemon: ACTIVE
✓ pveproxy: ACTIVE
✓ pvestatd: ACTIVE
✓ pve-firewall: ACTIVE
```

#### Cluster Mode
```
=== Base Services ===
✓ pvedaemon: ACTIVE
✓ pveproxy: ACTIVE
✓ pvestatd: ACTIVE
✓ pve-firewall: ACTIVE

=== Cluster Services ===
✓ pve-cluster: ACTIVE
✓ pve-ha-lrm: ACTIVE
✓ pve-ha-crm: ACTIVE
✓ corosync: ACTIVE
```

### 2. Check Cluster Status

#### Standalone Mode
```
╔════════════════════════════════════════╗
║     STANDALONE MODE DETECTED          ║
╚════════════════════════════════════════╝

This node is running in standalone mode.
No cluster configuration detected.

Node Information:
  Node Name: pve-node1
  Cluster Services: Not Applicable
```

#### Cluster Mode
```
╔════════════════════════════════════════╗
║       CLUSTER MODE DETECTED           ║
╚════════════════════════════════════════╝

=== Cluster Information ===
Cluster name: production-cluster
Config version: 5
Nodes: 3
Quorate: Yes

=== Cluster Nodes ===
[Full node list with status]

=== Corosync Status ===
[Corosync service details]
```

### 3. Check Storage Status

#### Standalone Mode
```
Mode: Standalone - Showing local storages only

=== Proxmox Storage Status ===
[Local storage only]
```

#### Cluster Mode
```
Mode: Cluster - Showing all cluster storages

=== Proxmox Storage Status ===
[All cluster storages]

=== Shared Storage (Cluster) ===
[Only shared/replicated storage]
```

### 4. Test Cluster Quorum

#### Standalone Mode
```
╔════════════════════════════════════════╗
║     STANDALONE MODE DETECTED          ║
╚════════════════════════════════════════╝

Quorum is not applicable in standalone mode.
This feature is only available when the node is part of a cluster.
```

#### Cluster Mode
```
=== Quorum Status ===
Quorate: Yes
✓ Cluster has quorum

=== Expected Votes ===
Expected votes: 3
Total votes: 3

=== Cluster Members ===
[Member details with vote information]
```

### 5. Check VM/Container Status

#### Standalone Mode
```
Mode: Standalone - Showing local VMs/Containers only

=== Virtual Machines ===
[Local VMs only]
Total VMs on this node: 5

=== Containers ===
[Local containers only]
Total Containers on this node: 3
```

#### Cluster Mode
```
Mode: Cluster - Showing VMs/Containers across all nodes

=== Cluster Resources ===
[Cluster-wide VM/CT list with node locations]

=== Virtual Machines (This Node: pve-node1) ===
[VMs on this specific node]
Total VMs on this node: 2

=== Containers (This Node: pve-node1) ===
[Containers on this specific node]
Total Containers on this node: 1
```

### 6. Stop All Services

#### Standalone Mode
```
WARNING: This will stop all Proxmox services!
Are you sure? (yes/no):
```

#### Cluster Mode
```
WARNING: This will stop all Proxmox services!
WARNING: This node is part of a cluster!
Stopping cluster services may affect HA and cluster operations.
Are you sure? (yes/no):
```

## Safety Features in Cluster Mode

### Enhanced Warnings

When performing potentially disruptive operations in cluster mode:

1. **Stopping Services**
   - Extra warning about cluster impact
   - Mentions HA service disruption
   - Confirms cluster awareness

2. **Restarting Services**
   - Notes about brief cluster communication interruption
   - Informs about service restart order

### Proper Service Ordering

- **Start**: Base services first, then cluster services
- **Stop**: Cluster services first, then base services (reverse order)
- **Restart**: Maintains proper dependencies

## Visual Indicators

### Header Display

Every screen shows the current mode:

**Standalone:**
```
================================================
     Proxmox Master Management Script
================================================
Mode: Standalone | Node: pve-node1
================================================
```

**Cluster:**
```
================================================
     Proxmox Master Management Script
================================================
Mode: Cluster | Cluster Name: production-cluster
Node: pve-node1
================================================
```

### Color Coding

- 🟢 **Green**: Active/Healthy/Success
- 🔴 **Red**: Inactive/Failed/Critical
- 🟡 **Yellow**: Warning/Information
- 🔵 **Blue**: Section headers
- 🟦 **Cyan**: Mode indicators
- 🟣 **Magenta**: Cluster/Node names

## Diagnostic Report Differences

### Report Header

**Standalone:**
```
=========================================
Proxmox Diagnostic Report
Generated: [timestamp]
Node: pve-node1
Mode: STANDALONE
=========================================
```

**Cluster:**
```
=========================================
Proxmox Diagnostic Report
Generated: [timestamp]
Node: pve-node1
Mode: CLUSTER
Cluster Name: production-cluster
=========================================
```

### Report Sections

**Common to Both:**
- System Information
- Proxmox Version
- Base Service Status
- Storage Status
- Network Interfaces
- Disk Usage
- Memory Usage
- Failed Services
- Recent Errors

**Cluster Mode Only:**
- Cluster Service Status (separate section)
- Cluster Status (detailed)
- VM/Container Status (Cluster-wide)
- Quorum Information

## Best Practices

### For Standalone Nodes

1. Focus on base service health
2. Monitor local resources
3. Regular backups of local VMs
4. Storage capacity planning

### For Cluster Nodes

1. Always check quorum before operations
2. Monitor cluster-wide resources
3. Be aware of HA implications
4. Coordinate maintenance windows
5. Check cluster status after service restarts
6. Verify all nodes after changes

## Troubleshooting

### Script Shows Wrong Mode

If the script incorrectly identifies your node mode:

1. **Check cluster files:**
   ```bash
   ls -la /etc/pve/corosync.conf
   ls -la /etc/corosync/corosync.conf
   ```

2. **Verify cluster status:**
   ```bash
   pvecm status
   ```

3. **If files exist but shouldn't:**
   - You may have leftover cluster configuration
   - Consider cleaning up if node was removed from cluster

### Cluster Services Not Showing

If you're in a cluster but cluster services aren't managed:

1. Ensure both configuration files exist
2. Check `pvecm status` output
3. Verify script has correct permissions
4. Re-run the script (detection happens at startup)

## Migration Scenarios

### Standalone → Cluster

When you join a standalone node to a cluster:
1. Run the script after cluster join
2. Script will automatically detect cluster mode
3. Cluster services will now be managed
4. All cluster features become available

### Cluster → Standalone

When you remove a node from a cluster:
1. Properly remove node from cluster
2. Clean up cluster configuration
3. Run the script
4. Script will detect standalone mode
5. Only base services will be managed

## Summary

The cluster-aware functionality makes the script intelligent and safe:
- ✅ No manual configuration needed
- ✅ Automatic detection
- ✅ Appropriate service management
- ✅ Context-aware warnings
- ✅ Mode-specific information
- ✅ Enhanced safety in cluster environments

This ensures you always see relevant information and manage only the appropriate services for your setup.
