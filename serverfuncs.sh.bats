#!/usr/bin/env bats
# vim: set et ai ts=4 sw=4:

_put=serverfuncs.sh
setup() {
  tdir=$(mktemp -d)
  # shellcheck source=./sysfuncs.sh
  . sysfuncs.sh
  # shellcheck source=./serverfuncs.sh
  . "$_put"
}

teardown() {
  rm -rf "$tdir"
}

@test "${_put}: findProcPathAndWorkingDirs check for user process and dir" {
  cat <<-"EOF" > $tdir/myscript
	#!/bin/sh
	sleep 1
EOF
  chmod +x $tdir/myscript
  # spawn script to check if it visible in the process list
  cd $tdir; ./myscript &
  _thepid=$!
  cd -
  run findProcPathAndWorkingDirs "$(getUid)"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "/proc/${_thepid}/cwd:$tdir"
  [ "$status" -eq 0 ]
  # wait on script with sleep to terminate
  wait
  findProcPathAndWorkingDirs "$(getUid)" > $tdir/newout
  [ "$status" -eq 0 ]
  grep -vq "/proc/${_thepid}/cwd:/$tdir" $tdir/newout
  [ "$status" -eq 0 ]
}

@test "${_put}: findProcPathAndWorkingDirs check for root process and dir" {
  cat <<-"EOF" > $tdir/myscript
	#!/bin/sh
	sleep 1
EOF
  chmod +x $tdir/myscript
  # spawn script to check if it visible in the process list
  sudo sh -c "cd $tdir; ./myscript & echo \$! >$tdir/thepid"
  _thepid=$(cat $tdir/thepid)
  run sudo sh -c ". $(pwd)/sysfuncs.sh; . $(pwd)/$_put; _FUN_TRC=0; findProcPathAndWorkingDirs 0"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "/proc/${_thepid}/cwd:$tdir"
  [ "$status" -eq 0 ]
  # wait on script with sleep to terminate
  wait
  run sudo sh -c ". $(pwd)/sysfuncs.sh; . $(pwd)/$_put; _FUN_TRC=0; findProcPathAndWorkingDirs 0 > $tdir/newout"
  [ "$status" -eq 0 ]
  grep -vq "/proc/${_thepid}/cwd:/$tdir" $tdir/newout
  [ "$status" -eq 0 ]
}

@test "${_put}: checkProcessWithName for non existing user process" {
  run checkProcessWithName "invalidProcess" "" "$(getUid)" "$(pwd)" 0
  [ "$status" -eq 1 ]
}

@test "${_put}: checkProcessWithName for user process and dir" {
  cat <<-"EOF" > $tdir/myscript
	#!/bin/sh
	sleep 1
EOF
  chmod +x $tdir/myscript
  # spawn script to check if it visible in the process list
  cd $tdir >/dev/null; ./myscript &
  _thepid=$!
  cd - >/dev/null
  run checkProcessWithName "myscript" "" "$(getUid)" "$tdir" 0
  [ "$status" -eq 0 ]
  [ "$output" = "$_thepid" ]
  # wait on script with sleep to terminate
  wait 2>/dev/null
}

@test "${_put}: checkProcessWithName for user process with args" {
  _a1=1; _a2=2;
  sleep $_a1 &
  _p1=$!
  sleep $_a2 &
  _p2=$!
  pgrep -a sleep >&2
  run checkProcessWithName "sleep" "$_a1" "$(getUid)" "$(pwd)" 1
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$_p1" ]
  run checkProcessWithName "sleep" "$_a2" "$(getUid)" "$(pwd)" 1
  [ "$status" -eq 0 ]
  echo [${output}] >&2
  [ "${lines[0]}" = "$_p2" ]
  # wait on script with sleep to terminate
  wait 2>/dev/null
}

