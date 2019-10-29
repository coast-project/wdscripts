#!/usr/bin/env bats

setup() {
  MY_PACKAGE_DIR=${MY_PACKAGE_DIR:=$(mktemp -d)}
  MY_SCONSTRUCT_LOCATION=${MY_SCONSTRUCT_LOCATION:=$(pwd)/SConstruct}
  MY_SCONS_DEBUGLOG_YML=${MY_SCONS_DEBUGLOG_YML:=$(pwd)/debuglog.yml}
  DIR_EXCLUDES="--exclude=$(pwd)/.tox --exclude=$(pwd)/.git"
  export MY_PACKAGE_DIR MY_SCONS_DEBUGLOG_YML MY_SCONSTRUCT_LOCATION DIR_EXCLUDES
  env | sort
  mkdir -p ${MY_PACKAGE_DIR}
  echo -e "from pkg_resources import require as pkg_require\\npkg_require([\"SConsider<0.5\"])\\nimport SConsider\\n" >$MY_SCONSTRUCT_LOCATION
  echo -e "version: 1\\nformatters:\\n  simple:\\n    format: \"%(asctime)s - %(name)s - %(levelname)s - %(message)s\"\\nhandlers:\\n  console:\\n    class: logging.StreamHandler\\n    level: DEBUG\\n    formatter: simple\\n    stream: ext://sys.stdout\\nloggers:\\n  simpleExample:\\n    level: DEBUG\\n    handlers: [console]\\n    propagate: no\\nroot:\\n  level: INFO\\n  handlers: [console]\\n" >$MY_SCONS_DEBUGLOG_YML
}

teardown() {
  rm -rf $MY_SCONSTRUCT_LOCATION $MY_SCONS_DEBUGLOG_YML ${MY_PACKAGE_DIR} $(pwd)/globals
}

@test "default build scripts target" {
  run eval LOG_CFG=$MY_SCONS_DEBUGLOG_YML scons -u $DIR_EXCLUDES scripts
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "scons: done building targets." ]
}

@test "build scripts package" {
  run eval LOG_CFG=$MY_SCONS_DEBUGLOG_YML scons -u $DIR_EXCLUDES --usetool=Package --package=$MY_PACKAGE_DIR scripts
  [ "$status" -eq 0 ]
  run echo "$(ls -tc1 $MY_PACKAGE_DIR/scripts/scripts/ | sort )"
  packaged_files_on_a_line="${lines[@]}"
  [ "${packaged_files_on_a_line}" = "bootScript.sh config.sh keepwds.sh pstackwrapper.sh serverfuncs.sh startprf.sh startwda.sh startwds.sh stopwds.sh sysfuncs.sh trapsignalfuncs.sh" ]
}
