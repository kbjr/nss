_nss()
{
	local cur opts
	cur="${COMP_WORDS[$COMP_CWORD]}"
	subcommands="init destroy start stop restart edit config global-config"
	COMPREPLY=( $(compgen -W "$subcommands" -- ${cur}) )
	return 0
}
complete -F _nss nss
