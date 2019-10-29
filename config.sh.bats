#!/usr/bin/env bats

setup() {
  printf "{\n\
	/Build		1398\n\
	/Release	4.0.1\n\
}" >Version.any
  printf "2.3.4" >VERSION
}

teardown() {
  rm -f Version.any VERSION
}

@test "wdapp is the default name of \$APP_NAME" {
  result="$(. config.sh >&2; echo $APP_NAME)"
  [ "$result" = "wdapp" ]
}

@test "version retrieval from anything \$PROJECTVERSION" {
  run eval "source config.sh >&2; printf \"\$PROJECTVERSION\\n\$VERSIONFILE\\n\""
  [ "${lines[0]}" = "4.0.1.1398" ]
  [ "${lines[1]}" = "$(pwd)/Version.any" ]
}

@test "version retrieval from VERSION" {
  # need to remove anything which has priority in retrieval
  rm -f Version.any
  run eval "source config.sh >&2; printf \"\$PROJECTVERSION\\n\$VERSIONFILE\\n\""
  [ "${lines[0]}" = "2.3.4" ]
  [ "${lines[1]}" = "$(pwd)/VERSION" ]
}
