########################################################################
#                                                                      #
#               This software is part of the ast package               #
#          Copyright (c) 1982-2011 AT&T Intellectual Property          #
#                      and is licensed under the                       #
#                 Eclipse Public License, Version 1.0                  #
#                    by AT&T Intellectual Property                     #
#                                                                      #
#                A copy of the License is available at                 #
#          http://www.eclipse.org/org/documents/epl-v10.html           #
#         (with md5 checksum b35adb5213ca9657e911e9befb180842)         #
#                                                                      #
#              Information and Software Systems Research               #
#                            AT&T Research                             #
#                           Florham Park NJ                            #
#                                                                      #
#                  David Korn <dgk@research.att.com>                   #
#                                                                      #
########################################################################
function err_exit
{
	print -u2 -n "\t"
	print -u2 -r ${Command}[$1]: "${@:2}"
	let Errors+=1
}
alias err_exit='err_exit $LINENO'

Command=${0##*/}
integer Errors=0

[[ -d $tmp && -w $tmp && $tmp == "$PWD" ]] || { err\_exit "$LINENO" '$tmp not set; run this from shtests. Aborting.'; exit 1; }

alias foo='print hello'
if	[[ $(foo) != hello ]]
then	err_exit 'foo, where foo is alias for "print hello" failed'
fi
if	[[ $(foo world) != 'hello world' ]]
then	err_exit 'foo world, where foo is alias for "print hello" failed'
fi
alias foo='print hello '
alias bar=world
if	[[ $(foo bar) != 'hello world' ]]
then	err_exit 'foo bar, where foo is alias for "print hello " failed'
fi
if	[[ $(foo \bar) != 'hello bar' ]]
then	err_exit 'foo \bar, where foo is alias for "print hello " failed'
fi
alias bar='foo world'
if	[[ $(bar) != 'hello world' ]]
then	err_exit 'bar, where bar is alias for "foo world" failed'
fi
if	[[ $(alias bar) != "bar='foo world'" ]]
then	err_exit 'alias bar, where bar is alias for "foo world" failed'
fi
unalias foo  || err_exit  "unalias foo failed"
alias foo 2> /dev/null  && err_exit "alias for non-existent alias foo returns true"
unset bar
alias bar="print foo$bar"
bar=bar
if	[[ $(bar) != foo ]]
then	err_exit 'alias bar, where bar is alias for "print foo$bar" failed'
fi
unset bar
alias bar='print hello'
if	[[ $bar != '' ]]
then	err_exit 'alias bar cause variable bar to be set'
fi
alias !!=print
if	[[ $(!! hello 2>/dev/null) != hello ]]
then	err_exit 'alias for !!=print not working'
fi
alias foo=echo
if	[[ $(print  "$(foo bar)" ) != bar  ]]
then	err_exit 'alias in command substitution not working'
fi
( unalias foo)
if	[[ $(foo bar 2> /dev/null)  != bar  ]]
then	err_exit 'alias not working after unalias in subshell'
fi
builtin -d rm 2> /dev/null
if	whence rm > /dev/null
then	[[ ! $(alias -t | grep rm= ) ]] && err_exit 'tracked alias not set'
	PATH=$PATH
	[[ $(alias -t | grep rm= ) ]] && err_exit 'tracked alias not cleared'
fi
if	hash -r 2>/dev/null && [[ ! $(hash) ]]
then	PATH=$tmp:$PATH
	for i in foo -foo --
	do	print ':' > $tmp/$i
		chmod +x $tmp/$i
		hash -r -- $i 2>/dev/null || err_exit "hash -r -- $i failed"
		[[ $(hash) == $i=$tmp/$i ]] || err_exit "hash -r -- $i failed, expected $i=$tmp/$i, got $(hash)"
	done
else	err_exit 'hash -r failed'
fi
( alias :pr=print) 2> /dev/null || err_exit 'alias beginning with : fails'
( alias p:r=print) 2> /dev/null || err_exit 'alias with : in name fails'

unalias no_such_alias && err_exit 'unalias should return non-zero for unknown alias'

# ======
# Adding a utility after resetting the hash table should work
hash -r chmod
[[ $(hash) == "chmod=$(whence -p chmod)" ]] || err_exit $'resetting the hash table with `hash -r \'utility\'` doesn\'t work correctly'

# ======
# Attempting to unalias a previously set alias twice should be an error
alias foo=bar
unalias foo
unalias foo && err_exit 'unalias should return non-zero when a previously set alias is unaliased twice'

# Removing the history and r aliases should work without an error from free(3)
err=$(set +x; { "$SHELL" -i -c 'unalias history; unalias r'; } 2>&1) && [[ -z $err ]] \
|| err_exit "the 'history' and 'r' aliases can't be removed (got $(printf %q "$err"))"

# ======
exit $((Errors<125?Errors:125))
