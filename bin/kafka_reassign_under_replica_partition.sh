#!/bin/bash 
source /root/.bashrc 2>/dev/null 

##########
Usage ()
##########
{
clear 
cat << !END
DESCRIPTION
	Use this program to move some replicas for certain partitions over to a particular broker.
	This tool exclude a broker id from the list of replica for an under replicated partiton, replace it by a a random broker id and build the json file use by the kafka-reassign-partitions.sh
	
	However, this tool use the program kafka-reassign-partitions.sh
	Typically, if you end up with an unbalanced cluster, you can use the tool in this mode to selectively move partitions around.
	In this mode, the tool takes a single file which has a list of partitions to move and the replicas that each of those partitions should be assigned to
	(More information : https://)
	
OPTIONS
	--topic				Mandatory		Name of the topic (all if you want to control all the topics)
	--broker-exclude	Mandatory		Filter to exclude broker id (reg)
	--broker-include	Optional		Filter to include broker id (reg). Deprecated
	--limit 			Optional		Limit then nimber of reassign (by default 3)
	--mode				Mandatory		How to execute the program execute : 
										  execute : reassign will be execute
										  verify :  any action, the reassign command is print
	--debug			Mandatory			Set debug (set -x)
!END

exit 2 
}

################
f_IsNumeric ()
################
{

if [[ $1 != +([0-9]) ]]; then
	echo "ERROR One value must be numeric"
	exit 2
}

############################
########### MAIN ###########
############################
trap 'echo "CTRL-C was pressed" ; f_Trap 1' 2
trap 'echo "CTRL-D was pressed" ; f_Trap 1' 2
trap 'echo "CTRL-Z was pressed" ; f_Trap 1' 2


########### Checking options 
OPTS=$(getopt -o h --long help,topic:,broker-exclude:,broker-include:,limit:,mode:,debug, -- "$@")
[ $? != 0 ] && Usage

eval set -- "$OPTS"

while true ; do
	case "$1" in
		--topic) opt_topic=$2 ; shift 2 ;;
		--broker-exclude) opt_idEx=$2 ; shift 2 ;;
		--broker-include) opt_idIn=$2 ; shift 2 ;;
		--limit) opt_limit=$2 ; shift 2 ;;
		--mode) opt_mode=$2 ; shift 2 ;;
		--debug) opt_debug=1 ; shift ;;
		-h|--help) Usage ; shift ;;
		--) shift ; break
	esac
done

[[ $debug -eq 1 ]] && set -x


# Check mandatory option
if [ -z "${opt_idEx}" -o -z "${opt_mode}" ] && Usage

case $opt_mode in
	execute) EXEC="" ;;
	verify) EXEC="echo" ;;
	*|?) Usage ::
esac


###### Program variable
# Build the log file
typeset ve_Date=$(date + "%Y%m%_%H%M%S")
typeset whoami=$( who am i | awk '{ print $1 }' )
typeset shellName=$(basename $0)
typeset logFile="/.../log/${shellName}.${opt_mode}.${ve_Date}.${whoami).log.tmp"
typeset logOutFile="/.../log/${shellName}.${opt_mode}.${ve_Date}.${whoami).out.log.tmp"
typeset reasignementEile="/.../log/${shellName}.${opt_mode}.${ve_Date}.${whoami).json"

# Communicate with Kafka
typeset zookeeperQuorum=$(grep -w zookeeper.connect /etc/kafka/conf/server.properties | cut -d"=" -f2)
typeset kafkaQuorum="kafka_server:9095 kafka_server:9095" 
typeset RafkaBinPath="/usr/hdp/current/kafka-broker/bin"

# Internal variable
typeset -i isExist=0 
typeset brokerIdEx 
typeset brokerIdln
typeset limit 

# Verify syntax and affect
if [[ -n "$opt_idEx" ]]; then
	f_IsNumeric $opt_idEx
	brokerIdEx=" | egrep -v \"${opt_idEx}\""
fi
if [[ -n "$opt_idIn" ]]; then
	f_IsNumeric $opt_idIn
	brokerIdIn=" | egrep -v \"${opt_idIn}\""
fi
if [[ -n "$opt_limit" ]]; then
	f_IsNumeric $opt_limit
	limit=" | head - \"${opt_limit}\""
else
	limit=" | head -3"
fi

[[ -n "${opt_topic}" ]] && topicPattern=" | egrep \"${opt_topic\"" 

# Build the json header
echo '{"version":1,' > ${reasignementFile}
echo '{"partitions":[' >> ${reasignementFile}

# Browse the under replicated partitions

eval ${kafkaBinPath}/kafka-topucs.sh --zookeeper ${zookeeperQuorum} --describe --under-replicad-partitions ${topicPattern} ${limit} | ( while read underList
do
	_isExist=1
	
	# Assign internal variable
	_topic=$(echo $underList | awk '{ print $2 }' | sed "s/ //g")
	_partition=$(echo $underList | awk '{ print $4 }' | sed "s/ //g")
	_replica=$(echo $underList | awk '{ print $8 }' | sed "s/ //g")
	
	eval shuf -i1001-1007 ${brokerIdEx} ${brokerIdIn} | ( while read idList
	 do
		echo $replica | grep -w idList >/dev/null 2>&1
		[[ $? -eq 1 ]] && _newReplica=$(echo $_replica | sed "s/$opt_idEx/$idList/")
	done
	
	# Build the json body
	echo "{\"topic\":\"$_topic\",\"partition\":$_partition,\"replicas\":[$_newReplica]}," >> ${reasignementFile}
	)
done

# Delete the last json character (,) to replace by the footer
sed -i '$ s/.$/]}/' ${reasignementFile}

# Execute or print the reassign command
[[ $_isExist -eq 1 ]] && execute ${kafkaBinPath}/kafka-reassign-partitions.sh --zookeeper ${zookeeperQuorum} --reassignment-json-file ${reasignementFile} --execute || echo "WARNING : nothing replica reassign "
)
f_Trap 0