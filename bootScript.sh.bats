#!/usr/bin/env bats

_put=bootScript.sh
setup() {
  tdir=$(mktemp -d)
  tdir2=$(mktemp -d)
  tdir3=$(mktemp -d)
  initdir=$(mktemp -d)
  tdir_config=${tdir}/config
  tdir_scripts=${tdir}/scripts
  tdir_lnscripts=${tdir}/lnscripts
  mkdir -p ${tdir_scripts} ${tdir_config} ${tdir2}/logs/rotate
  ln -s ${tdir_scripts} ${tdir_lnscripts}
  tar cf - *.sh | tar xf - -C ${tdir_scripts}
  sed -e 's|SERVERNAME=.*|APP_NAME="Guguseli"\nSERVERNAME="Testservice"|' -e 's|PRJ_DESCRIPTION=.*|PRJ_DESCRIPTION="Bats Testservice"|' ${tdir_scripts}/prjconfig.sh >${tdir_config}/prjconfig.sh
  ln -sf ${tdir_lnscripts}/bootScript.sh ${initdir}/S10test
}

teardown() {
  rm -rf ${tdir} ${tdir2} ${tdir3} ${tdir_scripts} ${tdir_config}
}

# /tmp/tmp.1
# ├── config
# ├── lnscripts -> /tmp/tmp.1/scripts
# └── scripts
@test "${_put}: Abort when command is missing" {
  tree -d $tdir
  run eval "cd ${tdir}; PRINT_DBG=3 ./scripts/bootScript.sh;"
  echo $output
  [ "$status" -eq 1 ]
}

# /tmp/tmp.1
# ├── config
# ├── lnscripts -> /tmp/tmp.1/scripts
# └── scripts
@test "${_put}: Abort when sourced" {
  tree -d $tdir
  run eval "cd ${tdir};source scripts/bootScript.sh status"
  echo $output
  [ "$status" -eq 2 ]
}

# /tmp/tmp.1
# ├── config
# ├── lnscripts -> /tmp/tmp.1/scripts
# └── scripts
@test "${_put}: Succeed with status command (relative call)" {
  tree -d $tdir
  run eval "cd ${tdir}; ./scripts/bootScript.sh status"
  echo $output
  [ "$status" -eq 0 ]
}

# /tmp/tmp.1
# ├── config
# ├── lnscripts -> /tmp/tmp.1/scripts
# └── scripts
@test "${_put}: Succeed with status command (absolute call)" {
  tree -d $tdir
  run eval "cd ${tdir}; ${tdir_scripts}/bootScript.sh status"
  echo $output
  [ "$status" -eq 0 ]
}

# /tmp/tmp.1
# ├── config
# ├── lnscripts -> /tmp/tmp.1/scripts
# └── scripts
@test "${_put}: Succeed with status command (absolute call in linked dir)" {
  tree -d $tdir
  run eval "cd ${tdir}; ${tdir_lnscripts}/bootScript.sh status"
  echo $output
  [ "$status" -eq 0 ]
}

# /tmp/tmp.1
# ├── config
# ├── lnscripts -> /tmp/tmp.1/scripts
# └── scripts
# /tmp/tmp.initdir
# └── S10test -> /tmp/tmp.1/lnscripts/bootScript.sh
# /tmp/tmp.2
# └── logs
#     └── rotate
# /tmp/tmp.3
# ├── config -> /tmp/tmp.1/config
# ├── logs -> /tmp/tmp.2/logs
# └── scripts -> /tmp/tmp.1/scripts
@test "${_put}: Succeed with status command (absolute call with init like linked script)" {
  for d in config scripts; do ln -s ${tdir}/$d ${tdir3}/$d; done
  ln -s ${tdir2}/logs ${tdir3}/logs
  tree ${initdir}
  tree -d $tdir $tdir2 $tdir3
  run eval "cd ${tdir3}; ${initdir}/S10test -D status"
  echo $output
  [ "$status" -eq 0 ]
#  [ "${lines[0]}" = "${tdir3}" ]
}

