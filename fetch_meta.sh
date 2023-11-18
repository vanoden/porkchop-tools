#!/bin/bash
###########################################
### Fetch Tag Data from link-local		###
### instance metadata.  Output as JSON	###
### string.  Used for chef automation.	###
### A. Caravello 11/17/2023				###
###########################################

# Get a temporary token
TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300"` 

# Variable to hold json string
JSON=

# Fetch tag values
for key in Customer Level Role Environment
do
	if [ -z "$JSON" ]; then
		# Prepend curly brace
		JSON=$JSON"{ ";
	elif [ ! -z "$JSON" ]; then
		# Append comma
		JSON=$JSON", ";
	fi

	value=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/$key`
	JSON="${JSON}\"${key}\": \"${value}\""
done
JSON=$JSON" }"

echo -n $JSON
