#!/usr/bin/env bats

_put=config.sh
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
 	cat <<-"EOF" >${tdir_scripts}/test_config.sh
	#!/bin/sh
	mypath=$(dirname $0)
	test "/" = "$(echo ${mypath} | cut -c1)" || mypath="$(cd ${mypath} 2>/dev/null && pwd)"
	cd "$1"
	shift 1
	. $mypath/config.sh;
	eval $*
EOF
	chmod +x ${tdir_scripts}/test_config.sh
	printf "2.3.4" >${tdir_config}/VERSION
}

teardown() {
  rm -rf ${tdir} ${tdir2} ${tdir3} ${tdir_scripts} ${tdir_config}
}

@test "${_put}: wdapp is the default name of \$APP_NAME" {
	run ${tdir_scripts}/test_config.sh "." echo \$APP_NAME
	[ "${lines[0]}" = "wdapp" ]
}

@test "${_put}: version retrieval from Version.any" {
  run ${tdir_scripts}/test_config.sh "${tdir}" echo \$PROJECTVERSION
  [ "${lines[0]}" = "4.0.1.1398" ]
  run ${tdir_scripts}/test_config.sh "${tdir}" echo \$VERSIONFILE
  [ "${lines[0]}" = "${tdir_config}/Version.any" ]
}

@test "${_put}: version retrieval from VERSION" {
  # need to remove anything which has priority in retrieval
  rm -f ${tdir_config}/Version.any
  run ${tdir_scripts}/test_config.sh "${tdir}" echo \$PROJECTVERSION
  [ "${lines[0]}" = "2.3.4" ]
  run ${tdir_scripts}/test_config.sh "${tdir}" echo \$VERSIONFILE
  [ "${lines[0]}" = "${tdir_config}/VERSION" ]
}

# /tmp/tmp.cQEx0cZ7xR
# ├── config
# └── scripts
@test "${_put}: PROJECTDIR setting from samedir" {
  run ${tdir_scripts}/test_config.sh "${tdir}" echo \$PROJECTDIR
  tree -d $tdir
  echo $output
  [ "${lines[0]}" = "${tdir}" ]
}

# /tmp/tmp.cQEx0cZ7xR
# ├── config
# └── scripts
@test "${_put}: PROJECTDIR setting from subdir" {
  run ${tdir_scripts}/test_config.sh "${tdir_scripts}" echo \$PROJECTDIR
  tree -d $tdir
  echo $output
  [ "${lines[0]}" = "${tdir}" ]
}

# /tmp/tmp.KQ6AdNvese
# ├── config
# ├── lnscripts -> /tmp/tmp.KQ6AdNvese/scripts
# └── scripts
@test "${_put}: PROJECTDIR setting from linked subdir" {
  ln -s ${tdir_scripts} ${tdir_lnscripts}
  run ${tdir_lnscripts}/test_config.sh "${tdir_lnscripts}" echo \$PROJECTDIR
  tree -d $tdir
  echo $output
  [ "${lines[0]}" = "${tdir}" ]
}

# /tmp/tmp.KQ6AdNvese
# ├── config
# ├── lnscripts -> /tmp/tmp.KQ6AdNvese/scripts
# └── scripts
@test "${_put}: PROJECTDIR setting from linked subdir absolute" {
  ln -s ${tdir_scripts} ${tdir_lnscripts}
  tree -d $tdir
  run ${tdir_lnscripts}/test_config.sh "${tdir_config}" echo \$PROJECTDIR
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
@test "${_put}: PROJECTDIR setting from within projectpath with linked subdirs" {
  mkdir -p ${tdir}/logs
  for d in config logs scripts; do ln -s ${tdir}/$d ${tdir2}/$d; done
  tree -d $tdir $tdir2
  run ${tdir2}/scripts/test_config.sh "${tdir2}" echo \$PROJECTDIR
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
@test "${_put}: PROJECTDIR setting from within config subdir of projectpath with linked subdirs" {
  mkdir -p ${tdir}/logs
  for d in config logs scripts; do ln -s ${tdir}/$d ${tdir2}/$d; done
  tree -d $tdir $tdir2
  run ${tdir2}/scripts/test_config.sh "${tdir2}/config" echo \$PROJECTDIR
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
@test "${_put}: PROJECTDIR setting from within logs subdir of projectpath with linked subdirs" {
  mkdir -p ${tdir}/logs
  for d in config logs scripts; do ln -s ${tdir}/$d ${tdir2}/$d; done
  tree -d $tdir $tdir2
  run ${tdir2}/scripts/test_config.sh "${tdir2}/logs" echo \$PROJECTDIR
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
@test "${_put}: PROJECTDIR setting from within logs/rotate subdir of projectpath with linked subdirs" {
  mkdir -p ${tdir2}/logs/rotate
  for d in config scripts; do ln -s ${tdir}/$d ${tdir3}/$d; done
  ln -s ${tdir2}/logs ${tdir3}/logs
  tree -d $tdir $tdir2 $tdir3
  run ${tdir3}/scripts/test_config.sh "${tdir3}/logs/rotate" echo \$PROJECTDIR
  echo $output
  [ "${lines[0]}" = "${tdir3}" ]
}
