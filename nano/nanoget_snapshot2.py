#!/usr/bin/python3

import sys
import os
import time

sys.path.append(os.path.dirname(__file__))

import nanoget

try:
    if len(sys.argv) >= 2:
        if sys.argv[1] == "-h":
            print(f"Usage: {sys.argv[0]} [-h] [sensor-ip-address]")
            print(f"Default ip-address: {nanoget.UDP_IP}")
            exit(1)
        nanoget.UDP_IP = sys.argv[1]

    res = nanoget.get_record()
    print(time.time(), *res)

    time.sleep(1.5)
    res = nanoget.get_record()
    print(time.time(), *res)
except:
    pass
