#!/bin/bash
for name in `find . "(" -name 'Access.log.*' -o -name 'Error.log.*' -o -name 'DBAccess.log.*' -o -name 'DBError.log.*' -o -name 'Import.log.*' -o -name 'MethodTime.log.*' -o -name 'Trace.log.*' ")" -type f -print`; do
	echo "removing file ["$name"]";
	rm -f $name;
done
