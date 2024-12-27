#!/usr/bin/python3

import argparse
import os
import sys
import hashlib
import bcrypt
import sqlite3
sys.path.append("/usr/libexec/pzsvrtool")
import pzsvrtool_common

# Took the formula from https://github.com/quarantin/pz-server-tools
def md5(string):
	m = hashlib.md5()
	m.update(string.encode('utf-8'))
	return m.digest().hex().encode('utf-8')

def digest(string):
	salt = b'$2a$12$O/BFHoDFPrfFaNPAACmWpu'
	return bcrypt.hashpw(md5(string), salt).decode('utf-8')

parser = argparse.ArgumentParser(description="Change Project Zomboid's user password", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("-username", help="Name of the user", required=True)
parser.add_argument("-password", help="New Password", required=True)
args = parser.parse_args()
username = args.username
password = args.password

sqlPath = os.path.expanduser("~/Zomboid/db/%s.db") % (pzsvrtool_common.get_config_value(os.path.expanduser("~/pzsvrtool/pzsvrtool.config"), "zomboidServerName"))
connection = sqlite3.connect(sqlPath)
cursor = connection.cursor()
cursor.execute("UPDATE whitelist SET password=? WHERE username=?", (digest(password), username))
connection.commit()
connection.close()