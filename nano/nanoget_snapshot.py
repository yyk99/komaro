#!/usr/bin/python3 

import sys
import os
import time

sys.path.append(os.path.dirname(__file__))

import nanoget

try:
	res = nanoget.get_record()
	print(time.time(), *res) 

	time.sleep(1.5)
	res = nanoget.get_record()
	print(time.time(), *res) 
except:
	pass

