#!/bin/sh

cat << EOF > awktags.foo
BEGIN{ first=0;}
{
	if (first == 1 && \$1 != "")
		print \$1;
	if (match(\$0,"Existing Tags:"))
		first=1;
}
EOF

cvs status -v $1 | awk -f awktags.foo

rm awktags.foo

