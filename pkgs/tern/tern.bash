# Adapted from Tern 0.9.9 shell integration; use the installed CLI outside Tern.
_tern() {
	builtin local cur="${COMP_WORDS[COMP_CWORD]}" rec word paths='' at='' w
	builtin local -a words
	words=()
	COMPREPLY=()
	for w in "${COMP_WORDS[@]:1:COMP_CWORD-1}"; do
		w=${w#[\"\']}
		words+=("${w%[\"\']}")
	done
	cur=${cur#[\"\']}
	while IFS= builtin read -r rec; do
		case $rec in
			:files) paths=f ;;
			:dirs) paths=d ;;
			':line '*) at=${rec#:line } ;;
			*$'\t'*$'\t'*)
				word=${rec#*$'\t'}
				word=${word%%$'\t'*}
				[[ $word == "$cur"* ]] && COMPREPLY+=("$word")
				;;
		esac
	done < <(\builtin command "@tern@" __complete "${words[@]}" "$cur" 2> /dev/null)
	if [[ -n $at ]]; then
		# Word N of those given is COMP_WORDS[N+1]; bash-completion
		# completes from there as from the start of a line.
		(( at += 1 ))
		if builtin declare -F _comp_command_offset > /dev/null; then
			_comp_command_offset "$at"
			builtin return
		elif builtin declare -F _command_offset > /dev/null; then
			_command_offset "$at"
			builtin return
		elif (( COMP_CWORD == at )); then
			paths=c
		else
			paths=f
		fi
	fi
	if [[ -n $paths ]]; then
		[[ $paths == c ]] || builtin compopt -o filenames 2> /dev/null
		while IFS= builtin read -r w; do
			COMPREPLY+=("$w")
		done < <(\builtin compgen -"$paths" -- "$cur" 2> /dev/null)
	fi
	for w in "${COMPREPLY[@]}"; do
		if [[ $w == *[[:space:]\"\'\\\$\`\;\&\|\<\>\(\)]* ]]; then
			builtin compopt -o filenames 2> /dev/null
			break
		fi
	done
}
complete -F _tern tern
