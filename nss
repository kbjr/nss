#!/usr/bin/env python3

import sys, os, json, argparse, signal, subprocess, shutil

NSS_PATH = sys.path[0]
SERVER_DIR = '.nss'
ACCESS_LOG_FILE = 'logs/access.log'
ERROR_LOG_FILE = 'logs/error.log'
CONTROLLER_FILE = 'controller.js'
PID_FILE = '.pid'

# ------------------------------------------------------------
#  Main function

def main():
	# If no arguments are given, display the list of sub-commands
	if len(sys.argv) == 1 or sys.argv[1] == '-h' or sys.argv[1] == '--help':
		print('nss - Node.js Simple Server')
		print('Copyright 2011 James Brumond')
		print('Dual licensed under MIT and GPL\n')
		print('These are the available sub-commands:')
		print('  init           - create a new http server in the current directory')
		print('  destroy        - destroy the http server in the current directory')
		print('  start          - start the http server')
		print('  stop           - stop the http server')
		print('  restart        - restart the http server')
		print('  edit           - edit the http server\'s controller')
		print('  config         - edit the http server\'s configuration')
		print('  global-config  - edit the default configuration')
	# Otherwise, create the argument parser
	else:
		
		# -------------------------------------------------------------------------
		#  Argument parsing configuration
		
		parser = argparse.ArgumentParser()
		sub_parsers = parser.add_subparsers()
		
		# We use the --deepest flag on a lot of commands, so store the help up here
		deepest_flag_help = 'If multiple servers are found in the current tree, always reference the deepest one'
		
		# nss init
		init_parser = sub_parsers.add_parser('init')
		
		# nss destroy [-b]
		destroy_parser = sub_parsers.add_parser('destroy')
		destroy_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
		
		# nss start [-b]
		start_parser = sub_parsers.add_parser('start')
		start_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
		
		# nss stop [-b]
		stop_parser = sub_parsers.add_parser('stop')
		stop_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
		
		# nss restart [-b]
		restart_parser = sub_parsers.add_parser('restart')
		restart_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
		
		# nss edit [--editor EDITOR] [-b]
		edit_parser = sub_parsers.add_parser('edit')
		edit_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
		edit_parser.add_argument('-e', '--editor', action='store', default=None,
			help='Choose what editor to use to edit the config file')
		
		# nss config [-b] KEY VALUE
		config_parser = sub_parsers.add_parser('config')
		config_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
		config_parser.add_argument('key', action='store',
			help='The configuration setting to change')
		config_parser.add_argument('value', action='store',
			help='The new value to set in the configuration')
			
		# nss global-config KEY VALUE
		gconfig_parser = sub_parsers.add_parser('global-config')
		gconfig_parser.add_argument('key', action='store',
			help='The configuration setting to change')
		gconfig_parser.add_argument('value', action='store',
			help='The new value to set in the configuration')
		
		# Parse the arguments
		args = parser.parse_args()
		
		# -------------------------------------------------------------------------
		#  Select the correct function
		
		subcommand = sys.argv[1]
		if subcommand == 'init':
			init(args)
		elif subcommand == 'destroy':
			destroy(args)
		elif subcommand == 'start':
			start(args)
		elif subcommand == 'stop':
			stop(args)
		elif subcommand == 'restart':
			restart(args)
		elif subcommand == 'edit':
			edit(args)
		elif subcommand == 'config':
			config(args)
		elif subcommand == 'global-config':
			global_config(args)
		else:
			sys.stderr.write('Invalid argument')

# ------------------------------------------------------------
#  These functions represent the sub-commands

def init(args):
	"""
	  Used for `nss init'
	"""
	doInit = True
	serverPath = _find_up_tree(default=True, errorOnNotFound=False)
	if serverPath:
		print('A server was already found at ' + serverPath)
		doInit = input('Create a new server at the current level? [y/n] ') in 'yY'
	if doInit:
		print('Initializing new server...')
		shutil.copytree(
			os.path.join(NSS_PATH, '.nss-server-template'),
			os.path.join(os.getcwd(), SERVER_DIR)
		)

def destroy(args):
	"""
	  Used for `nss destroy'
	"""
	serverPath = _find_up_tree(default=args.deepest)
	print('Destroying server...')
	shutil.rmtree(serverPath)

def start(args):
	"""
	  Used for `nss start'
	"""
	serverPath = _find_up_tree(default=args.deepest)
	print('Starting the server...')
	pidFile = os.path.join(serverPath, PID_FILE)
	if os.path.isfile(pidFile):
		pid = None
		with open(pidFile, 'r') as f:
			try:
				pid = int(f.read())
			except:
				pid = None
		if pid:
			_error('Server is already running. (did you mean nss restart?)')
	with open(os.path.join(serverPath, ACCESS_LOG_FILE), 'a') as f_access_log:
		with open(os.path.join(serverPath, ERROR_LOG_FILE), 'a') as f_error_log:
			subprocess.Popen([os.path.join(serverPath, 'server.js')], stdout=f_access_log, stderr=f_error_log)

def stop(args):
	"""
	  Used for `nss stop'
	"""
	serverPath = _find_up_tree(default=args.deepest)
	pidFile = os.path.join(serverPath, PID_FILE)
	if os.path.isfile(pidFile):
		pid = None
		with open(pidFile, 'r') as f:
			try:
				pid = int(f.read())
			except:
				pid = None
		if pid:
			print('Stopping the server...')
			try:
				os.kill(pid, signal.SIGINT)
			except:
				pass
			with open(pidFile, 'w') as f:
				f.write('0')

def restart(args):
	"""
	  Used for `nss restart'
	"""
	stop(args)
	start(args)

def edit(args):
	"""
	  Used for `nss edit'
	"""
	if args.editor:
		editor = args.editor
	else:
		editor = _load_global_config(key='editor', default='vi')
	controller = os.path.join(_find_up_tree(default=args.deepest), CONTROLLER_FILE)
	subprocess.Popen(['/usr/bin/env', editor, controller]).wait()

def config(args):
	"""
	  Used for `nss config {key} {value}'
	"""
	configFile = os.path.join(_find_up_tree(default=args.deepest), 'config.json')
	_edit_json_file(configFile, args.key, args.value)

def global_config(args):
	"""
	  Used for `nss global-config {key} {value}'
	"""
	configFile = os.path.join(NSS_PATH, '.nss-server-template/config.json')
	_edit_json_file(configFile, args.key, args.value)

# ------------------------------------------------------------
#  Internal functions

def _find_up_tree(default=False, errorOnNotFound=True):
	"""
	  Finds a server directory at or above the current directory level.
	  If none is found, an error is displayed. If more than one is found,
	  the user is asked which to use (unless a default param is given).
	"""
	found = [ ]
	foundIndex = 0
	current = os.getcwd()
	# Search up the tree for servers
	while True:
		path = os.path.join(current, SERVER_DIR)
		if os.path.isdir(path):
			found.append(path)
		if current == '/':
			break
		current = os.path.dirname(current)
	# If none were found, show an error
	if len(found) == 0:
		if errorOnNotFound:
			_error('Not an nss server (or any of the parent directories)')
		else:
			return None
	# If more than one was found and no --use-bottom flag was found, ask which to use
	if len(found) > 1 and not default:
		print('More than one nss server was found in your current tree.')
		for i in range(len(found)):
			print('  ' + (i + 1) + ': ' + found[i])
		foundIndex = int(input('Which would you like to use? ')) - 1
		if foundIndex + 1 > len(found):
			_error('Invalid value given')
	return found[foundIndex]
	
def _error(msg):
	"""
	  Write a message to stderr and exit
	"""
	sys.stderr.write(msg + '\n')
	sys.exit(1)
	
def _edit_json_file(filepath, key, value):
	"""
	  Edit a single key-value pair in the given JSON file
	"""
	content = None
	with open(filepath, 'r') as f:
		content = json.load(f)
	content[key] = value
	content = json.dumps(content, indent=4)
	with open(filepath, 'w') as f:
		f.write(content)

def _load_global_config(key=None, default=None):
	"""
	  Reads the global config file
	"""
	content = None
	filepath = os.path.join(NSS_PATH, '.nss-server-template/config.json')
	with open(filepath, 'r') as f:
		content = json.load(f)
	if key:
		if key in content:
			return content[key]
		else:
			return default
	else:
		return content

# ------------------------------------------------------------
#  Start running ...

if __name__ == '__main__':
	main()

# End of file simple.py
