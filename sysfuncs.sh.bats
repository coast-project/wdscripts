#!/usr/bin/env bats

_put=sysfuncs.sh
setup() {
	. ${_put} >&2
	tdir=$(mktemp -d)
	mkdir -p $tdir/testDir
	ln -s $tdir/testDir $tdir/lnDir
}

teardown() {
	rm -rf "$tdir"
}

@test "${_put}: isAbsPath / is absolute" {
  run isAbsPath /
  [ "$status" -eq 0 ]
}

@test "${_put}: isAbsPath . is not absolute" {
  run isAbsPath .
  [ "$status" -ne 0 ]
}

@test "${_put}: makeAbsPath of current dir (.)" {
  run makeAbsPath .
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$(pwd)" ]
}

@test "${_put}: makeAbsPath current dir (.) in other directory" {
  run makeAbsPath . "" "$tdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$tdir" ]
}

@test "${_put}: makeAbsPath subdir (testDir) in other directory" {
  run makeAbsPath testDir "" "$tdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$tdir/testDir" ]
}

@test "${_put}: makeAbsPath inexistent dir (blub) in other directory" {
  run makeAbsPath blub "" "$tdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "" ]
}

@test "${_put}: makeAbsPath softlink dir (lnDir) in other directory" {
  run makeAbsPath lnDir "" "$tdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$tdir/lnDir" ]
}

@test "${_put}: makeAbsPath resolved softlink dir (lnDir) in other directory" {
  run makeAbsPath lnDir "-P" "$tdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$tdir/testDir" ]
}

@test "${_put}: makeAbsPath of absolute directory" {
  run makeAbsPath "$tdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$tdir" ]
}

@test "${_put}: makeAbsPath of linked absolute directory" {
  run makeAbsPath "$tdir/lnDir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$tdir/lnDir" ]
}

@test "${_put}: makeAbsPath resolved of linked absolute directory" {
  run makeAbsPath "$tdir/lnDir" "-P"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$tdir/testDir" ]
}

@test "${_put}: isFunction for function" {
  run isFunction isAbsPath
  [ "$status" -eq 0 ]
}

@test "${_put}: isFunction for not existing function" {
  run isFunction blubby
  [ "$status" -ne 0 ]
}

@test "${_put}: isFunction for executable" {
  run isFunction sh
  [ "$status" -ne 0 ]
}

@test "${_put}: isFunction for builtin type" {
  run isFunction type
  [ "$status" -ne 0 ]
}

@test "${_put}: getUid for current user with defaults" {
  _myuid=$(id -u)
  run getUid
  [ "$output" = "$_myuid" ]
}

@test "${_put}: getUid with user name" {
  _myun=$(id -un)
  _myuid=$(id -u)
  run getUid "$_myun"
  [ "$output" = "$_myuid" ]
}

@test "${_put}: getUid for root user" {
  run getUid root
  [ "$output" = "0" ]
}

@test "${_put}: getCSVValue first of a:b:c" {
  run getCSVValue "a:b:c" 1
  [ "$output" = "a" ]
}

@test "${_put}: getCSVValue third of a:b:c:d" {
  run getCSVValue "a:b:c:d" 3
  [ "$output" = "c" ]
}

@test "${_put}: getCSVValue second of a b c d" {
  run getCSVValue "a b c d" 3 " "
  [ "$output" = "c" ]
}

@test "${_put}: printEnvVar with default formats" {
  _varkey=HOSTNAME
  _varvalue="$(eval echo \$"$_varkey")"
  _varoutput="$(printf "%-16s: [%s]\n" "$_varkey" "$_varvalue")"
  run printEnvVar "$_varkey"
  [ "$output" = "$_varoutput" ]
}

@test "${_put}: printEnvVar with own format" {
  _varkey=HOSTNAME
  _varvalue="$(eval echo \$"$_varkey")"
  _varoutput="$(printf "%s:%s\n" "$_varkey" "$_varvalue")"
  run printEnvVar "$_varkey" "%s:" "%s"
  [ "$output" = "$_varoutput" ]
}

