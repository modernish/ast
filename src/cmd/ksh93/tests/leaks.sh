########################################################################
#                                                                      #
#               This software is part of the ast package               #
#          Copyright (c) 1982-2012 AT&T Intellectual Property          #
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

[[ -d $tmp && -w $tmp ]] || { err\_exit "$LINENO" '$tmp not set; run this from shtests. Aborting.'; exit 1; }
builtin vmstate 2>/dev/null || { err\_exit "$LINENO" 'vmstate built-in command not compiled in; skipping tests'; exit 0; }

# Get the current amount of memory usage
function getmem
{
	vmstate --format='%(busy_size)u'
}
unit=bytes
n=$(getmem)
if	! let "$n == $n" 2>/dev/null	# not a number?
then	err\_exit "$LINENO" "'vmstate' output unexpected; tests cannot be run. (expected a number; got $(printf %q "$n"))"
	exit 1
fi

# test for variable reset leak #

function test_reset
{
	integer i N=$1

	for ((i = 0; i < N; i++))
	do	u=$i
	done
}

# Initialise variables used below to avoid false leaks
before=0 after=0 i=0 u=0

N=1000

# one round to get to steady state -- sensitive to -x

test_reset $N
test_reset $N
before=$(getmem)
test_reset $N
after=$(getmem)

if	(( after > before ))
then	err_exit "variable value reset memory leak -- $((after - before)) $unit after $N iterations"
fi

# buffer boundary tests

for exp in 65535 65536
do	got=$($SHELL -c 'x=$(printf "%.*c" '$exp' x); print ${#x}' 2>&1)
	[[ $got == $exp ]] || err_exit "large command substitution failed -- expected $exp, got $got"
done

data="(v=;sid=;di=;hi=;ti='1328244300';lv='o';id='172.3.161.178';var=(k='conn_num._total';u=;fr=;l='Number of Connections';n='22';t='number';))"
read -C stat <<< "$data"
before=$(getmem)
for ((i=0; i < 500; i++))
do	print -r -- "$data"
done |	while read -u$n -C stat
	do	:
	done	{n}<&0-
after=$(getmem)
(( after > before )) && err_exit "memory leak with read -C when deleting compound variable (leaked $((after - before)) $unit)"

# extra 'read's to get to steady state
for ((i=0; i < 10; i++))
do	read -C stat <<< "$data"
done
before=$(getmem)
for ((i=0; i < 500; i++))
do      read -C stat <<< "$data"
done
after=$(getmem)
(( after > before )) && err_exit "memory leak with read -C when using <<< (leaked $((after - before)) $unit)"

# ======
# Unsetting an associative array shouldn't cause a memory leak
# See https://www.mail-archive.com/ast-users@lists.research.att.com/msg01016.html
typeset -A stuff
before=$(getmem)
for (( i=0; i<1000; i++ ))
do
	unset stuff[xyz]
	typeset -A stuff[xyz]
	stuff[xyz][elem0]="data0"
	stuff[xyz][elem1]="data1"
	stuff[xyz][elem2]="data2"
	stuff[xyz][elem3]="data3"
	stuff[xyz][elem4]="data4"
done
unset stuff
after=$(getmem)
(( after > before )) && err_exit 'unset of associative array causes memory leak' \
	"(leaked $((after - before)) $unit)"

# ======
exit $((Errors<125?Errors:125))
