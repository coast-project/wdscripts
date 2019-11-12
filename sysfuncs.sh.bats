#!/usr/bin/env bats

_put=sysfuncs.sh
setup() {
  . ${_put} >&2
}

teardown() {
  true
}

@test "${_put}: isAbsPath / is absolute" {
  run isAbsPath /
  [ "$status" -eq 0 ]
}

@test "${_put}: isAbsPath . is not absolute" {
  run isAbsPath .
  [ "$status" -ne 0 ]
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

