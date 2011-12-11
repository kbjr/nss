_nss()
{
	local cur prev sub opts
	cur="${COMP_WORDS[$COMP_CWORD]}"
	prev="${COMP_WORDS[$COMP_CWORD - 1]}"
	sub="${COMP_WORDS[1]}"
	
	# Complete sub-commands
	if [ "$COMP_CWORD" == "1" ]
	then
		subcommands="init destroy start stop restart edit config global-config logs"
		COMPREPLY=( $(compgen -W "$subcommands" -- ${cur}) )
		return 0
	# Complete log files
	elif [ "$prev" == "logs" ]
	then
		COMPREPLY=( $(compgen -W "access error" -- ${cur}) )
		return 0
	# Complete controller files for init
	elif [ "$sub" == "init" ] &&  [ "$prev" == "-c" ]
	then
		COMPREPLY=( $(compgen -f ${cur}) )
		return 0
	fi
}
complete -F _nss nss
