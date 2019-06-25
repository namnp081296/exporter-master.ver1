#!/bin/bash


# How to use?
# /bin/bash parse_yml.sh -> list all parameters
# /bin/bash parse_yml.sh "mongo" -> list "mongo" parameter

CUR_DIR=`pwd`
FILE="$CUR_DIR/yaml_handler/exporter.yml"

if [[ -z $1 ]]; then
	while read -r line
	do
		if [[ $line == *"param:"* ]]; then
			echo $line | awk -F '"' '{print $2}' | awk -F '"' '{print $1}'
		fi
	done < $FILE
else
	QUERY="$1"
	EXE=0
	while read -r line
	do
		if [[ $EXE == 1 ]]; then
			echo $line | awk -F '"' '{print $2}' | awk -F '"' '{print $1}'
			EXE=0
		fi
		if [[ $line == *"$QUERY"* ]]; then
			EXE=1
		fi
	done < $FILE
fi
