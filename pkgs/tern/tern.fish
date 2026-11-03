# Adapted from Tern 0.9.9 shell integration; use the installed CLI outside Tern.
function __tern_complete --description "Completes tern's command line"
	set --local words (commandline -opc)[2..-1]
	set --local current (commandline -ct)
	set --local paths
	for rec in (command "@tern@" __complete $words $current 2>/dev/null)
		switch $rec
			case :files :dirs
				set paths $rec
			case ':line *'
				# Word N of those given starts a command line of its own.
				set --local at (math (string replace ':line ' '' -- $rec) + 1)
				set --local line (string join ' ' -- (string escape -- $words[$at..-1]) $current)
				complete -C "$line"
				return
			case '*'
				set --local parts (string split \t -- $rec)
				test (count $parts) -eq 3; and printf '%s\t%s\n' $parts[2] $parts[3]
		end
	end
	switch "$paths"
		case :files
			__fish_complete_path $current
		case :dirs
			__fish_complete_directories $current
	end
end

complete --command tern --no-files --arguments '(__tern_complete)'
