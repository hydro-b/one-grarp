one-grarp
=========

## VM_HOOK scripts to send Gratuitous ARP replies on behalf of VM's in OpenNebula cloud (ONE)

This project provides some scripts, and a hook to send Gratuitous ARP replies
on behalf of Virtual Machines (VM) that have been (live-)migrated from one
hypervisor to another in an OpenNebula managed cloud. Gratuitous ARP replies
may help (depending on router/switch configuration) hosts/routers to update
their ARP tables for the given IP address and let switches update their MAC
tables. As the MAC address for a VM doesn't change during live migration these
Gratuitous ARP replies primarily help to update switches MAC tables (which MAC
on which switch port).

# Platform requirements
The scripts have been made to work on a OpenNebula Cloud with QEMU/KVM as a hypervisor, libvirt as API to QEMU/KVM and OpenvSwitch
as the software bridge.  It should be fairly easy to adjust the scripts to
enable support for other hypervisors/bridges (i.e. Xen and "legacy" bridging).

# Software Requirements
- bash
- base64 (decode base64 encoded VM TEMPLATES of ONE)
- libxml-xpath-perl (providing xpath for XML path language
  http://www.w3.org/TR/xpath/)
**Make sure you've a patched copy where bug #68932 is fixed
(https://rt.cpan.org/Public/Bug/Display.html?id=68932, ubuntu:
https://bugs.launchpad.net/ubuntu/+source/libxml-xpath-perl/+bug/1321449).
xpath -q should be quiet or scripts won't work**
- perl (Data::Dumper)
- python (v2)
- scapy (python-scapy http://www.secdev.org/projects/scapy/)
- ovs-ofctl (OpenFlow control tool for OpenvSwitch)

# How does it work?
The bash script "segrarp.sh" is being executed on the HOST the VM starts
RUNNING when a VM_HOOK is being triggered by OpenNebula Daemon (oned). The
VM_HOOK provided is triggered when a VM is RUNNING and reaches state ACTIVE.
The segrarp.sh script uses the VM ID and the VM TEMPLATE as input. It uses
xpath to find out about the amount of NIC's in the VM TEMPLATE and the
corresponding BRIDGE, MAC address and IP address. The helper script
"ovs_in_port.pl" gets the in_port (the packet Ingress switch port) for a given
Port (vnet) on the OpenvSwitch. The script will temporarily add a flow to
OpenvSwitch to allow "MAC spoofing" (something being prevented by default ONE
rules). It will then use python script "grarp.py" to let the HOST send four
Gratuitous ARP replies on the virtual network interface of the VM.

# Installation
* Create a file called hook.tmpl with the following contents:

```
ARGUMENTS="$TEMPLATE"
COMMAND="segrarp.sh"
LCM_STATE="RUNNING"
REMOTE="NO"
RESOURCE="VM"
STATE="ACTIVE"
```

* Run `onehook create hook.tmpl
* Place the script "segrarp.sh" in the following directory on the OpenNebula
FRONTEND: /var/lib/one/remotes/hooks

* After that issue an "onehost sync --force" on the OpenNebula FRONTEND to push
the script to the /var/tmp/one/hooks directory on the HOSTS.

* Place the "grarp.py" and "ovs_in_port.pl" scripts in a directory which exists
in the PATH of the oneadmin user on the HOSTS.

* Place the "SUDO" file in the "/etc/sudoers.d" directory (Ubuntu / Debian) or
  include it in a main sudoers file.

# Tested environment
The scripts have been tested againts OpenNebula 4.6.1 on Ubuntu Trusty (14.04
LTS) FRONTEND with Ubuntu Saucy (13.10) HOSTS.

# Test
To test if the Gratuitous ARP replies are being send you can do the following:
* start a tcpdump on the VM:
 tcpdump -ennqti any arp and host $IP

* On the FRONTEND check the oned.log / syslog for messages coming back from the
"send_gratuitous_arp" hook.

* Issue a (live-)migration of the VM
