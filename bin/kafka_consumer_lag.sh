#!/bin/bash

source /root/.bashrc 2>/dev/null 

##########
Usage ()
##########
{
clear 
cat << !END
DESCRIPTION
	Check the lag for a consumer group
OPTIONS
	--consumer		Mandatory		Name of the consumer group
	--lag			Mandatory		Max lag value
	--topic			Optional		Name of the topic. If not indicate, it will be all the topic
	--summary		Optional		Prompt a summary on one line
	--debug			Optional		Set debug (set -x)
!END

exit 2 
}

###########
f_Trap ()
###########
{
rm -f  $(consumerGroupsFileTmp) 2>/dev/null 

exit $1

}

############################
########### MAIN ###########
############################
trap 'echo "CTRL-C was pressed" ; f_Trap 1' 2
trap 'echo "CTRL-D was pressed" ; f_Trap 1' 2
trap 'echo "CTRL-Z was pressed" ; f_Trap 1' 2


########### Variables
typeset zookeeperQuorum=$(grep -A1 ha.zookeeper.quorum /etc/hadoop/conf/core-site.xml | tail -1 | sed "s/[ ]*<value>\(.*\)<\/value>/\1/") 
typeset kafkaQuorum="<kafka_server:9095> <kafka_server:9095>" 
typeset kafkaPath="/usr/hdp/current/kafka-broker"
typeset consumerGroupsFileTmp="/tmp/conzumer-groups.$$"
typeset -i RET=0 
typeset -i partitionCount 
typeset -i partitionKo=0 
typeset -i partitionKoCount=0 
typeset -i topicKo=0 
typeset -i topicKoCount=0
typeset -i partitionOk=0 
typeset -i partitionOkCount=0 
typeset -i topicOkCount=0 
typeset -i isExist=0 
typeset -i partitionMaxLag=0

########### Checking options 
OPTS=$(getopt -o h --long help,topic:,consumer:,lag:,summary,debug, -- "$@")
[ $? != 0 ] && Usage

eval set -- "$OPTS"

while true ; do
	case "$1" in
		--topic) opt_topic=$2 ; shift 2 ;;
		--consumer) opt_consumerGroup=$2 ; shift 2 ;;
		--lag) opt_lag=$2 ; shift 2 ;;
		--summary) opt_summary=$2 ; shift ;;
		--debug) debug=1 ; shift ;;
		-h|--help) Usage ; shift ;;
		--) shift ; break
	esac
done

[[ $debug -eq 1 ]] && set -x 

# Check mandatory option
if [ -z "${opt_consumerGroup}" -o -z "${opt_lag}" ]; then
	Usage
fi

# Check value lag
if [[ "${opt_lag}" != +([0-9]) ]]; then
	echo "ERROR : Lag value must be numeric"
	exit 2
}

[[ -z ${opt_topic} ]] && topicArg="*" || topicArg="${opt_topic}"

sudo ${kafkaPath}/bin/kafka-consumer-groups.sh -zookeeper ${zookeeperQuorum} --describe --group ${opt_consumerGroup} > ${consumerGroupsFileTmp} 2>/dev/null
[[ $? -ne 0 ]] && echo "Error to execute ${kafkaPath}/bin/kafka-consumer-groups.sh" && f_Trap 2

cat ${consumerGroupsFileTmp} | awk '{ print $2 }' | egrep "${topicArg}" | grep -v "TOPIC" | uniq | ( while read topicLine
 do
	isExist=1
	partitionCount=$(awk '{ print $2 }' ${consumerGroupsFileTmp} | grep ${topicLine} | wc -l)
	partitionKo=$(awk '{ if ($2 == '\"$topicLine\"' && $6 > '$opt_lag' ) print $0 }' ${consumerGroupsFileTmp} | wc -l )
	if [[ $partitionKo -gt 0 ]]; then
		partitionMaxLag=$(awk '( if ($6 > '$opt_lag') print $6 }' ${consumerGroupsFileTmp} | sort -hr | head -1)
		let partitionKoCount=partitionKoCount+partitionKo
		let topicKoCount=topicKoCount+1
		RET=2
		
		[[ -z "${opt_summary}" ]] && echo "ERROR : The consumer group ${opt_consumerGroup} have $partitionKo partitions (on $partitionCount) for the topic $topicLine with the lag parameter value $opt_lag"
	else
		let topicOkCount=topicOkCount+1
		let partitionOkCount=partitionOkCount+partitionCount
		
		[[ -z "${opt_summary}" ]] && echo "OK : The consumer group ${opt_consumerGroup} have $partitionKo partitions (on $partitionCount) for the topic $topicLine with the lag parameter value $opt_lag"
	fi
done

if [[ $isExist -eq 0 ]]; then
	echo "ERROR : The consumer group $opt_consumerGroup contains any topic ($topicArg) with the lag parameter value $opt_lag"
	RET=2
fi

if [[ -n "${opt_summary}" ]]; then
	echo "The consumer group ${opt_consumerGroup} have $topicOkCount topic OK and ${topicKoCount} topic KO ($partitionKoCount partitions KO) for topic ${topicArg} with the lag parameter value $opt_lag. PLease check manually"
fi

f_Trap $RET
)