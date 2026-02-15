#!/usr/bin/python3 
#
#

import struct
import socket
import select

verbose = False
UDP_IP = "192.168.68.67"
UDP_PORT = 2390

def print_temperature():
    print (get_record())

def get_record():
    record = None
    MESSAGE = b"CONNECT\r\n"

    if verbose:
        print("UDP target IP: %s" % UDP_IP)
        print("UDP target port: %s" % UDP_PORT)
        print("message: %s" % MESSAGE)

    sock = socket.socket(socket.AF_INET, # Internet
                         socket.SOCK_DGRAM) # UDP
    sock.connect((UDP_IP, UDP_PORT))
    sock.sendto(MESSAGE, (UDP_IP, UDP_PORT))
    sock.setblocking(0)
    ready = select.select([sock], [], [], 10) # 10 seconds timeout
    if ready[0]:
        ok = sock.recv(1024)
        if verbose:
            print('ready:', ok)
        ready = select.select([sock], [], [], 10) # 10 seconds timeout
        if ready[0]:
            data = sock.recv(1024)
            if verbose:
                print('data', data, len(data))
            record = struct.unpack('<IiiiIII', data)
        else: # it is timeout
            print("Timeout...")
    else:
        print("Timeout...")
    CLOSE_MESSAGE = b"CLOSE\r\n"
    sock.sendto(CLOSE_MESSAGE, (UDP_IP, UDP_PORT))
    sock.close()
    return record

if __name__ == "__main__":
    print_temperature()
