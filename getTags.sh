echo staring in `dirname $0`
cvs status -v | awk -f `dirname $0`/getTagVersions.awk

