#!/usr/bin/env bats

setup() {
  . sysfuncs.sh >&2
}

teardown() {
  true
}

@test "isAbsPath / is absolute" {
  run isAbsPath /
  [ "$status" -eq 0 ]
}

@test "isAbsPath . is not absolute" {
  run isAbsPath .
  [ "$status" -ne 0 ]
}

