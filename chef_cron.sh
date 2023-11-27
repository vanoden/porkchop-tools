#!/bin/bash
###############################################
### chef_cron.sh							###
### cron runs this script to update files	###
### and execute chef-solo.					###
###############################################

# Folder Paths
CHEF_PATH="/etc/chef"
COOKBOOKS_PATH="$CHEF_PATH/cookbooks"
ROLES_PATH="$CHEF_PATH/roles"
ENVIRONMENTS_PATH="$CHEF_PATH/environments"
DATA_BAGS_PATH="$CHEF_PATH/data_bags"

# Get the Environment from instance
# Get a temporary token
TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300"`

# Fetch tag values
ENVIRONMENT=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/Environment`
ROLE=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/Role`

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

echo "Environment: $ENVIRONMENT"
echo "Role: $ROLE"

# Make sure the environment file is present
if [ ! -e "${ENVIRONMENTS_PATH}/${ENVIRONMENT}.json" ]; then
	echo "Environment file ${ENVIRONMENTS_PATH}/${ENVIRONMENT}.json not found";
	exit 1;
fi

# Update Cookbooks
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

# Update Roles
mkdir -p $ROLES_PATH
if [ -d "${ROLES_PATH}/.git" ]; then
	cd "${ROLES_PATH}"
	if ! git pull; then
		echo "Error updating roles"
		exit 1
	fi
else
	cd "$CHEF_PATH"
	if ! git clone https://github.com/vanoden/porkchop-roles ${ROLES_PATH}; then
		echo "Error cloning roles"
		exit 1
	fi
fi
cd -

# Write Chef Client Config
cat <<- EOF > /etc/chef/client.rb
	cookbook_path		'$COOKBOOKS_PATH'
	role_path			'$ROLES_PATH'
	environment_path	'$ENVIRONMENTS_PATH'
	data_bag_path		'$DATA_BAGS_PATH'

	environment			'$ENVIRONMENT'
	log_location		:syslog
	log_level			:info
EOF

# Run Chef Solo
/bin/chef-solo -c /etc/chef/client.rb -j /etc/chef/roles/$ROLE.json # > /var/log/chef-solo.log
