#!/bin/bash

# Script to start a new Project
# Preconditions:
#   - DEV_HOME und SNIFF_ITOPIA_TEMPLATES definiert
#   - $DEV_HOME/scripts ausgecheckt
#   - $DEV_HOME/WWW existiert
#   - $1 wurde angegeben -> Directory Name des neuen Projects, darf nicht schon unter $DEV_HOME/WWW existieren
#   - $2 template name(project type) i.e. Standard

if [ -n "$DEV_HOME" ]; then
	echo "DEV_HOME is" $DEV_HOME;
else
	echo "Please set DEV_HOME"
	exit 1;
fi
if [ -n "$SNIFF_ITOPIA_TEMPLATES" ]; then
	echo "SNIFF_ITOPIA_TEMPLATES is ["$SNIFF_ITOPIA_TEMPLATES"]";
else
	echo "Please set SNIFF_ITOPIA_TEMPLATES"
	exit 1;
fi

cd $DEV_HOME/WWW
if [ $? -ne 0 ]; then
  	printf "No WWW Directory in $DEV_HOME\n"
	printf "\nChecking out WDCore now..."
	cd ${DEV_HOME}
	cvs co WDCore
fi

NewProjectName=$1

if [ -n "$NewProjectName" ]; then
	# creating log directories
	if [ -d $DEV_HOME/WWW/$NewProjectName ]; then
		echo "$NewProjectName dir already exists"
		exit 1;
	else
		printf "Creating directory $DEV_HOME/WWW/$NewProjectName ... "
		mkdir -p $DEV_HOME/WWW/$NewProjectName
		if [ $? -ne 0 ]; then
			printf "failed\n"
			exit 1
		else
			printf "done\n"
		fi
	fi
else
	echo "usage: " `basename $0` "NewProjectName "
	exit 1;
fi

cd $NewProjectName

NewProjectType=$2

if [ -n "$NewProjectType" ]; then
	Project_Type=$NewProjectType
else
	Project_Type=Standard
fi

echo "using ProjectType of " $Project_Type

if [ ! -d ${DEV_HOME}/scripts ]; then
	printf "\nChecking out scripts...\n"
	cd ${DEV_HOME}
	cvs co scripts
fi

cd ${DEV_HOME}/WWW/${NewProjectName}
ln -s $DEV_HOME/scripts scripts

# remark - im Moment gibt es nur einen Projekttyp (Standard). Weitere könnten dann als zusätzliche 
# Unterverzeichnisse definiert werden.
echo "i am in: ["`pwd`"]"
tar cf - -C $SNIFF_ITOPIA_TEMPLATES/ProjectTemplate/$Project_Type . | tar xf -

# delete CVS dirs
find . -type d -name CVS -exec rm -rf {} \; > /dev/null 2>&1 

$SNIFF_ITOPIA_TEMPLATES/SetProjectName.pl $NewProjectName

mv ProjectName.shared $NewProjectName.shared

cd Docs

mv ProjectName $NewProjectName
mv $NewProjectName/ProjectName.shared $NewProjectName/$NewProjectName.shared

