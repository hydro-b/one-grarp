#!/bin/bash
#
# This script is executed on the HOST when a VM hook is triggered in the
# OpenNebula Daemon (oned, VM STATE RUNNING). It will send a gratuitous
# arp reply on behalf of the VM ($ID) on the designated vnet/ovswitch
# port of the VM. If a live-migrate is done for a VM, the gratuitous ARP
# reply makes sure all upstream switches update their MAC-address
# tables, and forward frames destined for the VM to the correct port(s)
# on the HOST.

T64=$1

if
    [ "$#" -le "2" ]
then
    echo "ERROR, please give a argument."
    exit 1
fi

xpath_bin=$(which xpath-patched)
[ -x "$xpath_bin" ] || fatal "xpath not found or not executable"

xpath="$xpath_bin -q -e"

grarp=$(which grarp.py)
[ -x "$grarp" ] || fatal "grarp.py not found or not executable"

ovs_in_port=$(which ovs_in_port.pl)
[ -x "$ovs_in_port" ] || fatal "ovs_in_port.pl not found or not executable"

ovsctl=$(which ovs-vsctl)
[ -x "$ovsctl" ] || fatal "ovs-vsctl not found or not executable"

virsh=$(which virsh)
[ -x "$virsh" ] || fatal "virsh not found or not executable"

sudo=$(which sudo)
[ -x "$sudo" ] || fatal "sudo not found or not executable"

base64=$(which base64)
[ -x "$base64" ] || fatal "base64 not found or not executable"

[ "$(id -u)" == "9869" ] || fatal "no. you no oneadmin."

# ONE template of vm (decoded)
TMPLT=$($base64 -d <<< $T64)

# libvirt template of VM
DEPLOY_ID=$($xpath "string(VM/DEPLOY_ID)" <<< $TMPLT)
LIBVIRT=$($virsh dumpxml $DEPLOY_ID)

# determine the # of NIC's in the VM
NR_NICS=$($xpath 'count(VM/TEMPLATE/NIC)' <<< $TMPLT)

# VM Name
NAME=$($xpath "VM/NAME" -e 'text()' <<< $TMPLT)

if
    [[ $NR_NICS = 0 ]]
then
    echo "No Network Interface in VM, not sending gratuitous ARP Reply"
    exit 0
fi

for NIC in $(eval echo "{1..$NR_NICS}"); do
   IP=$($xpath "string(VM/TEMPLATE/NIC[$NIC]/IP)" <<< $TMPLT)
   MAC=$($xpath "string(VM/TEMPLATE/NIC[$NIC]/MAC)" <<< $TMPLT)
   VNET=$($xpath "string(/domain/devices/interface/mac[@address='$MAC']/../target/@dev)" <<< $LIBVIRT)
   BRIDGE=$($xpath "string(/VM/TEMPLATE/NIC[$NIC]/BRIDGE)" <<< $TMPLT)
   IN_PORT=$($sudo $ovs_in_port $BRIDGE $MAC)

   if
      [ -z "$VNET" ]
   then
       echo "No VNET Interface found, unable to send gratuitous ARP Reply"
   else
       echo "Adding temporary OpenFlow rule to allow MAC spoofing on $VNET"
       $sudo ovs-ofctl add-flow $BRIDGE in_port=$IN_PORT,priority=50000,actions=normal
       echo "Sending 4 gratuitous ARP Replies (based on $MAC/$IP) on behalf of VM $NAME on VNET $VNET"
       $sudo $grarp -m $MAC -i $IP -v $VNET
       echo "Deleting temporary OpenFlow rule to prevent MAC spoofing on $VNET"
       $sudo ovs-ofctl --strict del-flows $BRIDGE in_port=$IN_PORT,priority=50000
   fi
done
