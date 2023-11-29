#!/bin/bash
################################################
### Configuration and Input Validation       ###
################################################
# Handle Input
if [ ! -z "$1" ]; then
	PARAM_1=$1
	PARAM_2=$2

	if `echo $PARAM_1|/usr/bin/grep -q -E ^[a-z0-9\\\-_]+\:\:[a-z0-9\\\-_]+$`; then
		RECIPE=$PARAM_1
	elif [ "$PARAM_1" == "update" ]; then
		if `echo $PARAM_2|/usr/bin/grep -q -E "^(cookbooks|roles|environment|client|data|all)$"`; then
			UPDATE=$PARAM_2
		else
			echo "Unrecognized key for update"
			exit 1
		fi
	else
		echo "Cannot parse input"
		exit 1
	fi
fi

# Folder Paths
CHEF_PATH="/etc/chef"
COOKBOOKS_PATH="$CHEF_PATH/cookbooks"
ROLES_PATH="$CHEF_PATH/roles"
ENVIRONMENTS_PATH="$CHEF_PATH/environments"
DATABAGS_PATH="$CHEF_PATH/data_bags"

################################################
### Get Instance Metadata and validate input ###
################################################
# Get a temporary token for the Instance Metadata
TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300"`

# Fetch tag values
ENVIRONMENT=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/Environment`
ROLE=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/Role`

# Validate the Environment and Role returned
if [ -z "$ENVIRONMENT" ]; then
	echo "Failed to get environment"
	exit 1;
fi
if [ -z "$ROLE" ]; then
	echo "Failed to get role"
	exit 1;
fi

if echo $ENVIRONMENT | grep "404" > /dev/null; then
	echo "Environment not found"
	exit 1;
fi

if echo $ROLE | grep "404" > /dev/null; then
	echo "Role not found"
	exit 1;
fi

BUCKET="${ENVIRONMENT}-deploy"

# Update Cookbooks
function update_cookbooks() {
	mkdir -p $COOKBOOKS_PATH
	if [ -d "${COOKBOOKS_PATH}/.git" ]; then
		cd "${COOKBOOKS_PATH}"
		if ! git pull; then
			echo "Error updating cookbooks"
			exit 1
		fi
	else
		cd "$CHEF_PATH"
		if ! git clone https://github.com/vanoden/porkchop-cookbooks ${COOKBOOKS_PATH}; then
			echo "Error cloning cookbooks"
			exit 1
		fi
	fi
	cd -
}

# Update Roles
function update_roles() {
	sudo mkdir -p $ROLES_PATH
	if [ -d "${ROLES_PATH}/.git" ]; then
		echo "Updating roles"
		cd "${ROLES_PATH}"
		if ! git pull; then
			echo "Error updating roles"
			exit 1
		fi
	else
		echo "Cloning roles"
		cd "$CHEF_PATH"
		if ! git clone https://github.com/vanoden/porkchop-roles ${ROLES_PATH}; then
			echo "Error cloning roles"
			exit 1
		fi
	fi
	cd -
}

# Update Databags
function update_databags() {
	SOURCE="s3://${BUCKET}/${ENVIRONMENT}/databags/"
	TARGET="${DATABAGS_PATH}/"

	sudo mkdir -p $TARGET
	echo "Syncing $SOURCE to $TARGET"
	result=`/usr/bin/aws s3 sync ${SOURCE} ${TARGET}`
}

# Write Chef Client Config
function update_client() {
	cat <<- EOF > /etc/chef/client.rb
		cookbook_path		'$COOKBOOKS_PATH'
		role_path			'$ROLES_PATH'
		environment_path	'$ENVIRONMENTS_PATH'
		data_bag_path		'$DATABAGS_PATH'

		environment			'$ENVIRONMENT'
		log_location		:syslog
		log_level			:info
	EOF
}

function update_environment() {
	SOURCE="s3://${BUCKET}/${ENVIRONMENT}.json"
	TARGET="${ENVIRONMENTS_PATH}/"

	echo "Copying $SOURCE to $TARGET"
	sudo mkdir -p $TARGET
	result=`/usr/bin/aws s3 cp $SOURCE $TARGET`
}

if [ "$UPDATE" == "cookbooks" ]; then
	update_cookbooks
	exit 0
elif [ "$UPDATE" == "environment" ]; then
	update_environment
	exit 0
elif [ "$UPDATE" == "data" ]; then
	update_databags
	exit 0
elif [ "$UPDATE" == "roles" ]; then
	update_roles
	exit 0
elif [ "$UPDATE" == "client" ]; then
	update_client
	exit 0
elif [ "$UPDATE" == "all" ]; then
	update_environment
	update_client
	update_databags
	update_cookbooks
	update_roles
	exit 0
fi

# Make sure the environment file is present
if [ ! -e "${ENVIRONMENTS_PATH}/${ENVIRONMENT}.json" ]; then
	echo "Environment file ${ENVIRONMENTS_PATH}/${ENVIRONMENT}.json not found";
	exit 1;
fi

# Run Chef Solo
PARAMS="-c /etc/chef/client.rb"
if [ -z "$RECIPE" ]; then
	# Run Role For Host
	PARAMS="${PARAMS} -j /etc/chef/roles/$ROLE.json"
else
	# Run Specified Recipe
	PARAMS="${PARAMS} -o $RECIPE"
fi

if [ -z "$PS1" ]; then
	# Automated, Output to Log
	/bin/chef-solo $PARAMS >> /var/log/chef-solo.log
else
	# Interactive, Output to Console
	/bin/chef-solo $PARAMS
fi
