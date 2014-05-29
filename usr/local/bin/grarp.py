#!/usr/bin/env python

from scapy.all import *
import argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-m", "--macaddress", help="source MAC address", required=True)
    parser.add_argument("-i", "--ipaddress", help="source IPv4 address", required=True)
    parser.add_argument("-v", "--vnet", help="source vnet interface", required=True)
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_args()
    sendp(Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(op=2, hwsrc=args.macaddress, psrc=args.ipaddress, hwdst="ff:ff:ff:ff:ff:ff", pdst="255.255.255.255"), iface=args.vnet, count=4, inter=0.2)
