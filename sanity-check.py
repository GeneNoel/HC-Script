import argparse
import os
import subprocess

parser = argparse.ArgumentParser(description='Sanity check for SYSTEM and NG-SCREENER')
parser.add_argument('-system', action='store_true', help='System check')
parser.add_argument('-ngscreener', action='store_true', help='NG-SCREENER check')
parser.add_argument('-demovm', action='store_true', help='Check on DemoVM')
args = parser.parse_args()

system_result = 0
ngscreener_result = 0
current_path = os.path.dirname(os.path.realpath(__file__)) + '/'

if not args.system and not args.ngscreener:
    args.system = "system"
    args.ngscreener = "ngscreener"

if args.system:
    if args.demovm:
        system_result = subprocess.call(['python', current_path + 'system-check.py', '-demovm'])
    else:
        system_result = subprocess.call(['python', current_path + 'system-check.py'])
if args.ngscreener:
    if args.demovm:
        ngscreener_result = subprocess.call(['python', current_path + 'software-check.py', '-demovm'])
    else:
        ngscreener_result = subprocess.call(['python', current_path + 'software-check.py'])

if system_result is 0 and ngscreener_result is 0:
    exit(0)
else:
    exit(1)
