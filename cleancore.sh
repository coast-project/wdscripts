#!/bin/bash
for name in `find . -name 'core' -type f -print`; do
	echo "removing file ["$name"]";
	rm -f $name;
done
