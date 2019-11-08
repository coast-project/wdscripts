#!/usr/bin/env bats

setup() {
  . sysfuncs.sh >&2
}

teardown() {
  true
}

@test "sysfuncs.sh: isAbsPath / is absolute" {
  run isAbsPath /
  [ "$status" -eq 0 ]
}

@test "sysfuncs.sh: isAbsPath . is not absolute" {
  run isAbsPath .
  [ "$status" -ne 0 ]
}

