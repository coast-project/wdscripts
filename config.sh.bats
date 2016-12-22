#!/usr/bin/env bats

setup() {
  true
}

teardown() {
  true
}

@test "wdapp is the default name of \$APP_NAME" {
  result="$(. config.sh >&2; echo $APP_NAME)"
  [ "$result" = "wdapp" ]
}
