#!/bin/sh -e
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2011, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# vim: set expandtab smarttab tabstop=2 sw=2:
# thanks to the snippets on http://mislav.uniqpath.com/2010/07/git-tips/
#

SHORTNAME=`basename $0`
LONGNAME=`cd \`dirname $0\` && pwd -P`/${SHORTNAME}
DRY_RUN="";

_add_remote()
{
    username=$1
    project=$2

    echo "No remote set, testing ssh://$username@${gerrithost}:${gerritport}"
    if ssh -p${gerritport} -o StrictHostKeyChecking=no $username@${gerrithost} gerrit ls-projects >/dev/null 2>&1
    then
        echo "$username@${gerrithost}:${gerritport} worked."
        echo "Creating a git remote called gerrit that maps to:"
        echo "  ssh://$username@${gerrithost}:${gerritport}/$project"
        git remote add gerrit ssh://$username@${gerrithost}:${gerritport}/$project
        return 0
    fi
    return 1
}

_check_remote()
{
    if ! git remote | grep gerrit >/dev/null 2>&1
    then
        origin_project=`git remote show origin | grep 'Fetch URL' | sed -r -e 's;^[^/]+//([^.:/]+\.)+([^.:/]+)(:[0-9]+)?[/:];;'`
        if add_remote $USERNAME $origin_project
        then
            return 0
        else
            echo "Your local name doesn't work on Gerrit."
            echo -n "Enter Gerrit username: "
            read gerrit_user
            if add_remote $gerrit_user $origin_project
            then
                return 0
            else
                echo "Can't infer where gerrit is - please set a remote named"
                echo "gerrit manually and then try again."
                echo
                echo "For more information, please see:"
                echo "\t${gerritinfowiki}"
                exit 1
            fi
        fi
    fi
}

# new and modified functions
isFunction() {
  type $1 | head -1 | egrep "^$1.*function\$" >/dev/null 2>&1;
}

die() { echo $@; exit 1; }

getGitRepositoryPath() {
  repoPath="`git rev-parse --show-toplevel 2>&1 || echo `";
  echo "${repoPath}";
}

inGitRepository() {
  git rev-parse --show-toplevel >/dev/null 2>&1;
}

toUpperChar() {
  echo "`echo $1 | cut -c1 | tr '[:lower:]' '[:upper:]'`";
}

yesNoWithDefault() {
  dflt=`toUpperChar $1`;
  read toConvert;
  answer=`toUpperChar $toConvert`
  if [ -n "$answer" ]; then
    test "$answer" = "Y";
  else
    test "$dflt" = "Y";
  fi
}

setGitConfig() {
  configKey="$1";
  configValue="$2";
  answerDefault="${3:-Y}";
  configOption="--global";
  if inGitRepository; then 
    askYesNoWithDefault "${answerDefault}" "It seems that you are inside a git repository. Shall we make\n\"${configKey}\" available for other repositories too (${configOption})?" || configOption="";
  fi
  partOfValue=`getConfigValue ${configKey} "" ${configOption}`;
  if [ -n "${partOfValue}" ]; then
    askYesNoWithDefault "N" "Override value \"${configKey}\"=\"${partOfValue}\"?" || return 0;
  fi;
  ${DRY_RUN} git config ${configOption} ${configKey} "${configValue}"
}

getLocalBranch() {
  value=`git symbolic-ref HEAD 2>/dev/null | sed -e 's|^refs/heads/||'`;
  echo "$value"
}

getRemoteBranch() {
  localBranch="`getLocalBranch`";
  test -n "${localBranch}" && value=`git config branch.${localBranch}.merge | sed -e 's|^refs/heads/||'`;
  echo "$value"
}

getRemoteName() {
  branchName="${1}";
  test -n "${branchName}" && value=`git config branch.${branchName}.remote`;
  echo "$value"
}

getConfigValue() {
  key="$1";
  dflt="$2";
  options="${3}";
  value="`git config ${options} --get $key 2>/dev/null || echo $dflt`";
  echo "$value"
}

getConfigValueRE() {
  reKey="$1";
  dflt="$2";
  options="${3}";
  value="`git config ${options} --get-regexp \"$reKey\" 2>/dev/null || echo $dflt`";
  echo "$value"
}

askYesNoWithDefault() {
  answerDefault=`toUpperChar ${1:-Y}`;
  question="$2";
  yesNoDefaults="y/N";
  test "${answerDefault}" = "Y" && yesNoDefaults="Y/n";
  printfTemplate="\n${question} [%s]";
  printf "${printfTemplate}" "${yesNoDefaults}";
  yesNoWithDefault ${answerDefault};
}

askUserInputWithDefault() {
  dflt="$1";
  varToSetBack="$2";
  question="$3";
  printfTemplate='\n%s\n(press enter to use default [%s]):';
#  dflt="`getConfigValue \"${key}\" \"${dflt}\"`";
  printf "${printfTemplate}" "${question}" "${dflt}";
  read answer;
  test -n "${answer}" || answer="${dflt}";
  eval ${varToSetBack}="'"${answer}"'";
}

getKeyDefaultValue() {
  keyname="$1";
  echo ${keyname} | egrep -q "^CONFIG_KEY(_\w+)+";
  if [ $? -eq 0 ]; then
    dfltkey="\$${keyname}_DEFAULT";
    dflt=`eval echo $dfltkey`;
  fi;
  echo "${dflt}";
}

askAndSetConfigValue() {
  key="$1";
  preferGlobal="$2";
  question="$3";
  dflt="$4";
  askedValue="";
  askUserInputWithDefault "`getConfigValue \"${key}\" \"${dflt}\"`" "askedValue" "${question}";
  askYesNoWithDefault "Y" "Please confirm setting \"${key}\"=\"${askedValue}\"?" && setGitConfig "${key}" "${askedValue}" "${preferGlobal}";
  return 0;
}

setupReviewAlias() {
  askAndSetConfigValue "alias.${CONFIG_KEY_ALIAS}" "Y" "Please confirm setting up a git \"${CONFIG_KEY_ALIAS}\" alias" "`getKeyDefaultValue CONFIG_KEY_ALIAS`";
}

ensureCommitMsgFile() {
  gerrithost=${1};
  gerritport=${2};
  baseDir=`getGitRepositoryPath`;
  hooksFile="hooks/commit-msg";
  localFileName="${baseDir}/.git/${hooksFile}";
  test -x "$localFileName" && return;
  if [ ! -r "$localFileName" ]; then
    test -n "${gerritport}" && gerritport="-P ${gerritport}";
    scpMsg=`scp -q ${gerritport} ${gerrithost}:${hooksFile} ${localFileName} 2>&1`;
    scpCode=$?;
  fi;
  if [ -n "${scpMsg}" ]; then
    echo scp failed with message [$scpMsg];
  else
    chmod +x $localFileName;
  fi;
  return ${scpCode:-0};
}

setupGerritHost() {
  remoteName=`findGerritRemoteName`;
  dfltUrl="";
  test -n "${remoteName}" && dfltUrl=`getConfigValue "remote.${remoteName}.url"`;
  test -n "${dfltUrl}" && setHostPortProjectFromUrl "${dfltUrl}";
  askAndSetConfigValue "${CONFIG_KEY_PREFIX}.${CONFIG_KEY_GHOST}" "N" "Please specify your gerrit remote host (without port!)" "`getKeyDefaultValue CONFIG_KEY_GHOST`";
  askAndSetConfigValue "${CONFIG_KEY_PREFIX}.${CONFIG_KEY_GPORT}" "N" "Please specify your gerrit remote port" "`getKeyDefaultValue CONFIG_KEY_GPORT`";
}

getProjectNameFromUrl() {
  echo $1 | sed -E "s/.*\///" | sed -E "s/\.git$//";
}

getPortFromUrl() {
  echo $1 | sed -E "s/.*:([0-9]*).*/\1/";
}

getHostFromUrl() {
  echo $1 | sed -E "s/ssh:\/\/([^:\/]*).*/\1/";
}

setHostPortProjectFromUrl() {
  remoteUrlValue="${1}";
  project=`getProjectNameFromUrl $remoteUrlValue`;
  CONFIG_KEY_GPORT_DEFAULT=`getPortFromUrl $remoteUrlValue`;
  CONFIG_KEY_GHOST_DEFAULT=`getHostFromUrl $remoteUrlValue`;
}

findGerritRemoteName() {
  keyValue="`getConfigValueRE \"^remote\..*\.push\$\"`";
  key="`echo $keyValue | cut -d' ' -f1`";
  value="`echo $keyValue | cut -d' ' -f2`";
  remote="";
  echo $value | grep "refs/for" >/dev/null 2>&1 && remote=`echo $key | cut -d'.' -f2`;
  test -z "${remote}" && remote="`getRemoteName \"\`getLocalBranch\`\"`";
  echo "${remote:-origin}";
}

setupRemoteTrackingBranch() {
  branchName=${1};
  #git branch --set-upstream ${branchName} "upstream";
}

setupEmail() {
  currentName="`getConfigValue \"user.name\"`";
  askAndSetConfigValue "user.name" "N" "Please verify or set your name" "${currentName}";
  currentEmail="`getConfigValue \"user.email\"`";
  askAndSetConfigValue "user.email" "N" "Please verify or set your email" "${currentEmail}";
}

setup() {
  setupReviewAlias;
  setupEmail;
  setupGerritHost;
  setupRebaseForTrackingBranches;
  ensureCommitMsgFile "`getConfigValue \"CONFIG_KEY_GHOST\" \"${CONFIG_KEY_GHOST_DEFAULT}\"`" "`getConfigValue \"CONFIG_KEY_GPORT\" \"${CONFIG_KEY_GPORT_DEFAULT}\"`";
}

show_config() {
  git config --get-regexp "^alias\.${CONFIG_KEY_ALIAS}" ||:
  git config --get-regexp "^${CONFIG_KEY_PREFIX}\..*" ||:
}

check_clean() {
  test -z "`git status --untracked-files=no --ignore-submodules=untracked --porcelain`";
}

getRemoteRef() {
  remoteName=`findGerritRemoteName`;
  test -n "${remoteName}" && remoteRef=${remoteName}/`getRemoteBranch`;
  echo "${remoteRef}";
}

isLocalBranchBehindRemote() {
  remoteName=`findGerritRemoteName`;
  test -z "${remoteName}" && die "Can not check up to date status without valid remote name.\n-> Check if your local branch is actually set up to track the correct remote branch.\nTo ";
  # update to latest remote changesets
  git fetch ${remoteName};
  remoteRef=`getRemoteRef`;
  localBranch=`getLocalBranch`;
  test -n "`hasBranchDiverged ${localBranch} ${remoteRef}`";
}

hasBranchDiverged() {
  base=${1};
  current=${2};
  # check for commits between base and current
  #  current ^base means commits from base to current -> see gitrevisions
  changes=`git log --oneline --no-decorate ${current} ^${base}`;
  echo "${changes}";
}

rebaseToRemote() {
  remoteRef=`getRemoteRef`;
  localBranch=`getLocalBranch`;
  echo "Local branch \"${localBranch}\" is behind \"${remoteRef}\"";
  askYesNoWithDefault "Y" "Should we proceed with \"git rebase ${remoteRef}\"?" || die "Aborting to let you do a manual rebase";
  git rebase ${remoteRef};
}

rebase() {
  check_clean || die "Cannot continue as there are uncommitted changes. Commit or stash
away before continueing.";
  # test preconditions we need for uploading
  isLocalBranchBehindRemote && rebaseToRemote;
}

upload() {
  # test preconditions we need for uploading
  rebase;
  # check if there are changes to be uploaded
  remoteRef=`getRemoteRef`;
  localBranch=`getLocalBranch`;
  test -n "`hasBranchDiverged ${remoteRef} ${localBranch}`" || die "No changes against ${remoteRef} detected, nothing to upload, aborting";
  # show what will be uploaded
  git log --graph --stat ${remoteRef}..;
  remotePrefix="refs/for";
  remoteName=`echo ${remoteRef} | cut -d'/' -f1`;
  uploadRef=${remotePrefix}/`echo ${remoteRef} | cut -d'/' -f2`/${localBranch};
#  askUserInputWithDefault "${uploadRef}" "askedValue" "Specify a short tag to append to \"${uploadRef}\" if needed (like ${localBranch})";
  uploadcommand="git push ${remoteName} HEAD:${uploadRef}";
  askYesNoWithDefault "Y" "Proceed uploading changes [\"${uploadcommand}\"]" || die "Aborting upload as requested";
  eval "${uploadcommand}";
}

setupRebaseForTrackingBranches() {
  msg="Setting up rebase for (remote) tracking branches is recommended as it does not
create unnecessary merge commits when you are behind the (remote) tracking branch.

Shall we set";
  key="branch.autosetuprebase"; askedValue="always"; preferGlobal="Y";
  askYesNoWithDefault "Y" "${msg} \"${key}\"=\"${askedValue}\"?" && setGitConfig "${key}" "${askedValue}" "${preferGlobal}";
  msg="To reduce the risk of pushing unwanted changes it is recommended to limit pushing
the current branch only.

Shall we set";
  key="push.default"; askedValue="tracking"; preferGlobal="Y";
  askYesNoWithDefault "Y" "${msg} \"${key}\"=\"${askedValue}\"?" && setGitConfig "${key}" "${askedValue}" "${preferGlobal}";
#  msg="make \`git pull\` on $local_branch always use rebase";
#  key="branch.$local_branch.rebase"; askedValue="true"; preferGlobal="N";
#  askYesNoWithDefault "Y" "${msg} \"${key}\"=\"${askedValue}\"?" && setGitConfig "${key}" "${askedValue}" "${preferGlobal}";
}

usage() {
  cat <<EOF

usage: $SHORTNAME [options] [[command] [command-options]]

  options:
    -n: dry-run mode, do not execute modifying commands

  commands:
    show-config: retrieve current configuration values
    setup: interactively setup gerrit-review

EOF
  exit 3;
}

while getopts :nh opt; do
  case $opt in
    n) DRY_RUN='echo DRY_RUN: would execute:\n\t';
       echo "\n<<< DRY_RUN MODE >>>\n";
    ;;
    h) # regular help asked
       usage;
    ;;
    \?) # catch all rule, introduced by leading ':' in option list
       test "$OPTARG" = "?" || echo "Invalid option [$OPTARG] specified, aborting";
       usage;
    ;;
  esac;
done
shift $((OPTIND -1))

CONFIG_KEY_PREFIX=greview
CONFIG_KEY_ALIAS=review
CONFIG_KEY_GHOST=gerrithost
CONFIG_KEY_GPORT=gerritport
CONFIG_KEY_GWIKIINFO=gerritwikiinfo
CONFIG_KEY_ALIAS_DEFAULT="!sh ${LONGNAME}" 
CONFIG_KEY_GHOST_DEFAULT=
CONFIG_KEY_GPORT_DEFAULT=
project="";

# source special config file from current repository with default values if available
inGitRepository && defaultsFileToSource="`getGitRepositoryPath`/.gerritdefaults"
test -r "$defaultsFileToSource" && . "$defaultsFileToSource"

gerriturl='${gerrithost}:${gerritport}'
givencommand=${1:-usage}
execfunc=`echo $givencommand | sed s/-/_/g`
isFunction $execfunc || die "requested function [$execfunc] (dash replaced) is not defined, check spelling"
test $# -gt 0 && shift
echo "calling function [${execfunc}] with arguments [$@]"
execcommand='$execfunc "$@"'
eval $execcommand
