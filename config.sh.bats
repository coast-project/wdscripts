#!/usr/bin/env bats

setup() {
  tdir=$(mktemp -d)
  tdir2=$(mktemp -d)
  tdir3=$(mktemp -d)
  tdir_config=${tdir}/config
  tdir_scripts=${tdir}/scripts
  tdir_lnscripts=${tdir}/lnscripts
  mkdir -p ${tdir_scripts} ${tdir_config}
  tar cf - *.sh | tar xf - -C ${tdir_scripts}
  printf "{\n\
	/Build		1398\n\
	/Release	4.0.1\n\
}" >${tdir_config}/Version.any
  printf "2.3.4" >${tdir_config}/VERSION
}

teardown() {
  rm -rf ${tdir} ${tdir2} ${tdir3} ${tdir_scripts} ${tdir_config}
}

@test "config.sh: wdapp is the default name of \$APP_NAME" {
  run eval "source config.sh >&2; printf \"\$APP_NAME\""
  [ "${output}" = "wdapp" ]
}

@test "config.sh: version retrieval from anything \$PROJECTVERSION" {
  run eval "cd ${tdir}; source scripts/config.sh >&2; printf \"\$PROJECTVERSION\\n\$VERSIONFILE\\n\""
  [ "${lines[0]}" = "4.0.1.1398" ]
  [ "${lines[1]}" = "${tdir_config}/Version.any" ]
}

@test "config.sh: version retrieval from VERSION" {
  # need to remove anything which has priority in retrieval
  rm -f ${tdir_config}/Version.any
  run eval "cd ${tdir}; source scripts/config.sh >&2; printf \"\$PROJECTVERSION\\n\$VERSIONFILE\\n\""
  echo $output
  [ "${lines[0]}" = "2.3.4" ]
  [ "${lines[1]}" = "${tdir_config}/VERSION" ]
}

# /tmp/tmp.cQEx0cZ7xR
# ├── config
# └── scripts
@test "config.sh: PROJECTDIR setting from samedir" {
  run eval "cd ${tdir}; source scripts/config.sh >&2; printf \"\$PROJECTDIR\""
  tree -d $tdir
  echo $output
  [ "${lines[0]}" = "${tdir}" ]
}

# /tmp/tmp.cQEx0cZ7xR
# ├── config
# └── scripts
@test "config.sh: PROJECTDIR setting from subdir" {
  run eval "cd ${tdir_scripts}; source config.sh >&2; printf \"\$PROJECTDIR\""
  tree -d $tdir
  echo $output
  [ "${lines[0]}" = "${tdir}" ]
}

# /tmp/tmp.KQ6AdNvese
# ├── config
# ├── lnscripts -> /tmp/tmp.KQ6AdNvese/scripts
# └── scripts
@test "config.sh: PROJECTDIR setting from linked subdir" {
  ln -s ${tdir_scripts} ${tdir_lnscripts}
  run eval "cd ${tdir_lnscripts}; source config.sh >&2; printf \"\$PROJECTDIR\""
  tree -d $tdir
  echo $output
  [ "${lines[0]}" = "${tdir}" ]
}

# /tmp/tmp.KQ6AdNvese
# ├── config
# ├── lnscripts -> /tmp/tmp.KQ6AdNvese/scripts
# └── scripts
@test "config.sh: PROJECTDIR setting from linked subdir absolute" {
  ln -s ${tdir_scripts} ${tdir_lnscripts}
  tree -d $tdir
  run eval "cd ${tdir_config}; source ${tdir_lnscripts}/config.sh >&2; printf \"\$PROJECTDIR\""
  echo $output
  [ "${lines[0]}" = "${tdir}" ]
}

# /tmp/tmp.1
# ├── config
# ├── logs
# └── scripts
# /tmp/tmp.2
# ├── config -> /tmp/tmp.1/config
# ├── logs -> /tmp/tmp.1/logs
# └── scripts -> /tmp/tmp.1/scripts
@test "config.sh: PROJECTDIR setting from within projectpath with linked subdirs" {
  mkdir -p ${tdir}/logs
  for d in config logs scripts; do ln -s ${tdir}/$d ${tdir2}/$d; done
  tree -d $tdir $tdir2
  run eval "cd ${tdir2}; source scripts/config.sh >&2; printf \"\$PROJECTDIR\""
  echo $output
  [ "${lines[0]}" = "${tdir2}" ]
}

# /tmp/tmp.1
# ├── config
# ├── logs
# └── scripts
# /tmp/tmp.2
# ├── config -> /tmp/tmp.1/config
# ├── logs -> /tmp/tmp.1/logs
# └── scripts -> /tmp/tmp.1/scripts
@test "config.sh: PROJECTDIR setting from within config subdir of projectpath with linked subdirs" {
  mkdir -p ${tdir}/logs
  for d in config logs scripts; do ln -s ${tdir}/$d ${tdir2}/$d; done
  tree -d $tdir $tdir2
  run eval "cd ${tdir2}/config; source ${tdir2}/scripts/config.sh; printf \"\$PROJECTDIR\""
  echo $output
  [ "${lines[0]}" = "${tdir2}" ]
}

# /tmp/tmp.1
# ├── config
# ├── logs
# └── scripts
# /tmp/tmp.2
# ├── config -> /tmp/tmp.1/config
# ├── logs -> /tmp/tmp.1/logs
# └── scripts -> /tmp/tmp.1/scripts
@test "config.sh: PROJECTDIR setting from within logs subdir of projectpath with linked subdirs" {
  mkdir -p ${tdir}/logs
  for d in config logs scripts; do ln -s ${tdir}/$d ${tdir2}/$d; done
  tree -d $tdir $tdir2
  run eval "cd ${tdir2}/logs; source ${tdir2}/scripts/config.sh; printf \"\$PROJECTDIR\""
  echo $output
  [ "${lines[0]}" = "${tdir2}" ]
}

# /tmp/tmp.1
# ├── config
# └── scripts
# /tmp/tmp.2
# └── logs
#     └── rotate
# /tmp/tmp.3
# ├── config -> /tmp/tmp.1/config
# ├── logs -> /tmp/tmp.2/logs
# └── scripts -> /tmp/tmp.1/scripts
@test "config.sh: PROJECTDIR setting from within logs/rotate subdir of projectpath with linked subdirs" {
  mkdir -p ${tdir2}/logs/rotate
  for d in config scripts; do ln -s ${tdir}/$d ${tdir3}/$d; done
  ln -s ${tdir2}/logs ${tdir3}/logs
  tree -d $tdir $tdir2 $tdir3
  run eval "cd ${tdir3}/logs/rotate; source ${tdir3}/scripts/config.sh; printf \"\$PROJECTDIR\""
  echo $output
  [ "${lines[0]}" = "${tdir3}" ]
}
