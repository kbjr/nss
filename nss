#!/usr/bin/env python3

import sys, os, json, argparse, signal, subprocess, shutil

# Constants
NSS_PATH         = sys.path[0]
SERVER_DIR       = '.nss'
LOG_DIR          = 'logs'
ACCESS_LOG_FILE  = 'access.log'
ERROR_LOG_FILE   = 'error.log'
CONTROLLER_FILE  = 'controller.js'
PID_FILE         = '.pid'
SERVER_TEMPLATE  = '.nss-server-template'

# ------------------------------------------------------------
#  Main function

def main():
		
	# -------------------------------------------------------------------------
	#  Argument parsing configuration
	
	parser = argparse.ArgumentParser(
		description = 'Creates (mostly) static Node.js http servers automatically'
	)
	sub_parsers = parser.add_subparsers()
	
	# We use the --deepest flag on a lot of commands, so store the help up here
	deepest_flag_help = 'If multiple servers are found in the current tree, always reference the deepest one'
	
	# nss init
	init_parser = sub_parsers.add_parser('init', help='Initialze a new nss server in the current directory')
	init_parser.add_argument('-c', '--with-controller', action='store', default=None,
		help='Link to the given filepath for the controller (instead of creating a new one')
	
	# nss destroy
	destroy_parser = sub_parsers.add_parser('destroy', help='Destroy an nss server in the current tree')
	destroy_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
	
	# nss start
	start_parser = sub_parsers.add_parser('start', help='Start an nss server in the current tree')
	start_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
	
	# nss stop
	stop_parser = sub_parsers.add_parser('stop', help='Stop an nss server in the current tree')
	stop_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
	
	# nss restart
	restart_parser = sub_parsers.add_parser('restart', help='Restart an nss server in the current tree')
	restart_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
	
	# nss edit [--editor EDITOR]
	edit_parser = sub_parsers.add_parser('edit', help='Edit an nss controller in the current tree')
	edit_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
	edit_parser.add_argument('-e', '--editor', action='store', default=None,
		help='Choose what editor to use to edit the config file')
	
	# nss config KEY VALUE
	config_parser = sub_parsers.add_parser('config', help='Configure an nss server in the current tree')
	config_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
	config_parser.add_argument('key', action='store',
		help='The configuration setting to change')
	config_parser.add_argument('value', action='store',
		help='The new value to set in the configuration')
		
	# nss global-config KEY VALUE
	gconfig_parser = sub_parsers.add_parser('global-config', help='Change global nss configuration settings')
	gconfig_parser.add_argument('key', action='store',
		help='The configuration setting to change')
	gconfig_parser.add_argument('value', action='store',
		help='The new value to set in the configuration')
	
	# nss logs {access|error}
	logs_parser = sub_parsers.add_parser('logs', help='Display logs for an nss server in the current tree')
	logs_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
	logs_parser.add_argument('log_file', action='store', choices=['access', 'error'],
		help='Which log file to view ("access" or "error")')
	logs_parser.add_argument('-l', '--lines', type=int, action='store', default=25,
		help='How many lines should be displayed from the end of the log (default: 25, 0 for all)')
	
	# nss npm ...
	npm_parser = sub_parsers.add_parser('npm', help='Run npm commands on an nss server in the current tree')
	npm_parser.add_argument('-d', '--deepest', action='store_true', help=deepest_flag_help)
	npm_parser.add_argument('npm_args', action='store', nargs='+',
		help='Arguments to be passed to npm')
	
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
	elif subcommand == 'logs':
		logs(args)
	elif subcommand == 'npm':
		npm(args)
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
			os.path.join(NSS_PATH, SERVER_TEMPLATE),
			os.path.join(os.getcwd(), SERVER_DIR)
		)
		if args.with_controller:
			controller = os.path.join(
				_find_up_tree(default=True, errorOnNotFound=False), 'controller.js'
			)
			os.unlink(controller)
			os.symlink(
				os.path.abspath(args.with_controller), controller
			)

def destroy(args):
	"""
	  Used for `nss destroy'
	"""
	serverPath = _find_up_tree(default=args.deepest)
	print('Destroying server...')
	stop(args)
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
	with open(os.path.join(serverPath, LOG_DIR, ACCESS_LOG_FILE), 'a') as f_access_log:
		with open(os.path.join(serverPath, LOG_DIR, ERROR_LOG_FILE), 'a') as f_error_log:
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

def logs(args):
	"""
	  Used for `nss logs {"access"|"error"}'
	"""
	serverPath = _find_up_tree(default=args.deepest)
	logFile = os.path.join(serverPath, LOG_DIR)
	if args.log_file == 'access':
		logFile = os.path.join(logFile, ACCESS_LOG_FILE)
	elif args.log_file == 'error':
		logFile = os.path.join(logFile, ERROR_LOG_FILE)
	with open(logFile, 'r') as f:
		f.seek(0, 2)
		fsize = f.tell()
		f.seek(max(fsize - 1024, 0), 0)
		lines = f.readlines()
	lines = ''.join(lines[-args.lines:])
	print(lines, end='')

def npm(args):
	"""
	  Used for `nss npm ...'
	"""
	argv = sys.argv[1:]
	argv.insert(0, '/usr/bin/env')
	subprocess.Popen(argv, cwd=_find_up_tree(default=args.deepest)).wait()

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
	# If more than one was found and no --deepest flag was found, ask which to use
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
	key = key.split('.')
	obj = content
	last = len(key) - 1
	for i in range(last):
		obj = obj[key[i]]
	content[key[last]] = value
	content = json.dumps(content, indent=4)
	with open(filepath, 'w') as f:
		f.write(content)

def _load_global_config(key=None, default=None):
	"""
	  Reads the global config file
	"""
	content = None
	filepath = os.path.join(NSS_PATH, SERVER_TEMPLATE, 'config.json')
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
