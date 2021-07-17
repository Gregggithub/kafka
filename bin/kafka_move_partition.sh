#!/bin/bash

##########
Usage ()
##########
{
clear 
cat << !END
DESCRIPTION
	Script to move partition inside a broker
OPTIONS
	--disk-value		Mandatory		Name of the consumer group
	--mode				Mandatory		How to execute the program execute : 
										  run : all the task will be execute
										  verify :  any action, comand wil be display
	--debug				Mandatory		Set debug (set -x)
!END

exit 2 
}

###########
execute ()
###########
{
typeset -i eRET=0

${EXEC} ${SUDO} $*
if [[ $? -eq 0 ]]; then
	logLevel=2
	eRET=0
else
	logLevel=4
	eRET=1
fi
return $eRET
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

# Variables
typeset zookeeperQuorum=$(grep -w zookeeper.connect /etc/kafka/conf/server.properties | cut -d"=" -f2) # with port 2181
typeset kafkaPath="/usr/hdp/current/kafka-broker"
typeset -i outputTail=1
typeset bkpPath="/.../$(date + "%Y%m%_%H%M%S")"
typeset tmpPath="/.../tmp"
typeset shellName=$(basename $0)
typeset serverName=$(hostname | tr [A-Z] [a-z])
typeset whoami=$( who am i | awk '{ print $1 }' )

########### Checking options 
OPTS=$(getopt -o h --long help,disk-value:,mode:,debug, -- "$@")
[ $? != 0 ] && Usage

eval set -- "$OPTS"

while true ; do
	case "$1" in
		--disk-value) output=$2 ; shift 2 ;;
		--mode) opt_mode=$2 ; shift 2 ;;
		--debug) opt_debug=1 ; shift ;;
		-h|--help) Usage ; shift ;;
		--) shift ; break
	esac
done

# Check mandatory option
if [ -z "${output}" -o -z "${opt_mode}" ]; then
	Usage
	f_Trap 1
fi

[[ $debug -eq 1 ]] && set -x

case $opt_mode in
	execute) EXEC="" ;;
	verify) EXEC="echo" ;;
	*|?) Usage ;;
esac


if [[ $output != +([0-9]) ]]; then
	echo "ERROR : Disk value must be numeric"
	f_Trap 1
fi

# 
kafkaIsStart=$(ps -fu kafka | grep /usr/lib/ambari-metrics-kafka-sink/ambari-metrics-kafka-sink.jar | wc -l)
if [ $kafkaIsStart -ne 0 -a "$opt_mode" == "run" ]; then
	echo "Kafka is running"
	f_Trap 1
}

case $opt_mode in
	run) EXEC="" ;;
	verify) EXEC="echo" ;;
	*|?) eco "ERROR : Mode must be run or verify" ; f_Trap 1 ;;
esac

# Create home directory
${EXEC} mkdir -p ${bkpPath}

df -h | grep data | awk '{ print $5";"$6 }' | sort -rh | head -${output} > ${tmpPath}/disk.top
df -h | grep data | awk '{ print $5";"$6 }' | sort -rh | tail -${output} > ${tmpPath}/disk.head


echo "---------------------------------------"
echo "------------  Information"
echo "Server:		$serverName"
echo "User:			$whoami"
echo ""

while read lineDisk
 do
	disk=$(echo $lineDisk | cut -d";" -f2)
	du -sh ${disk}/kafka-logs/* | grep G | sort -rh | head -1 > ${tmpPath}/partition.tmp
	
	while read linePartition
	 do
		size=$(echo $linePartition | awk '{ print $1 }')
		partition=$(echo $linePartition | awk '{ print $2 }')
		partitionNumber=$(echo $partition | cut -d"-" -f3)
		topic==$(echo $partition | cut -d"/" -f4 | cut -d"-" -f1)
		
		echo "------------ Step to move ${topic}"
		echo "Beginning:	${date}"
		
		lineDiskFromMove=$( tail -${outputTail} ${tmpPath}/disk.head | head -1)
		diskToMove=$( echo $lineDiskFromMove | cut -d";" -f2)
		sizeToMove=$( echo $lineDiskFromMove | cut -d";" -f1)
		
		echo "Action:			move from $partition ($size) do $diskToMove/kafka-logs/ ${sizeToMove}"
		
		## Move the partition
		${EXEC} mv $partition $diskToMove/kafka-logs/
		
		## Backup files
		${EXEC} cp $diskToMove/kafka-logs/replication-offset-checkpoint ${bkpPath}/$diskToMove.replication-offset-checkpoint
		${EXEC} cp $diskToMove/kafka-logs/recovery-point-offset-checkpoint ${bkpPath}/$diskToMove.recovery-point-offset-checkpoint
		
		${EXEC} cp $disk/kafka-logs/replication-offset-checkpoint ${bkpPath}/$disk.replication-offset-checkpoint
		${EXEC} cp $disk/kafka-logs/recovery-point-offset-checkpoint ${bkpPath}/$disk.recovery-point-offset-checkpoint
		
		# Search value of checkpoint offset and number of partition of the current disk
		fromReplicationOffset=$( grep "$topic $partitionNumber" $disk/kafka-logs/replication-point-offset-checkpoint)
		fromRecoveryOffset=$( grep "$topic $partitionNumber" $disk/kafka-logs/recovery-point-offset-checkpoint)
		fromBrokerPartitionNumber=$( sed -n 2p $disk/kafka-logs/replication-offset-checkpoint)
		
		# Update files checkpoint offset and number of partition on new disk
		${EXEC} echo $fromReplicationOffset >> $diskToMove>kafka-logs/replication-offset-checkpoint
		${EXEC} echo $fromRecoveryOffset >> $diskToMove>kafka-logs/recovery-offset-checkpoint
		
		toBrokerPartitionNumber=$(sed -n 2p $diskToMove/kafka-logs/recovery-offset-checkpoint)
		let toBrokerPartitionNumberIncrease=toBrokerPartitionNumber+1
		${EXEC} sed -i "s/${toBrokerPartitionNumber}$/${toBrokerPartitionNumberIncrease}/" $diskToMove/kafka-logs/replication-offset-checkpoint $diskToMove/kafka-logs/recovery-point-offset-checkpoint
		
		
		## Update files checkpoint offset and number of partition on new disk
		# Delete old references of topic in files
		${EXEC} sed -i "s/${fromReplicationOffset}/d" $disk/kafka-logs/replication-offset-checkpoint
		${EXEC} sed -i "s/${fromRecoveryOffset}/d" $disk/kafka-logs/recovery-offset-checkpoint
		
		# Replace number of partition
		let fromBrokerPartitionNumberDecrease=fromBrokerPartitionNumber-1
		${EXEC} se -i "s/*${fromBrokerPartitionNumber}$/${fromBrokerPartitionNumberDecrease}/" $disk/kafka-logs/replication-offset-checkpoint $disk/kafka-logs/recovery-point-offset-checkpoint
		
		let outputTail=outputTail+1
		
		echo "End:	${date}"
		echo "Partition to move:									$partition"
		echo "Partition to receive:									$diskToMove/kafka-logs"
		echo "Number of partition disk $disk (old - new):			$fromBrokerPartitionNumber - $fromBrokerPartitionNumberDecrease"
		echo "Number of partition disk $diskToMove (old - new):		$toBrokerPartitionNumber - $toBrokerPartitionNumberIncrease"
		echo ""
		if [[ -f ${tmpPath}/move.partition.stop]]; then
			echo "Flag file move.partition.stop		STOP PROGRAM"
			break
		fi
	done < ${tmpPath}/partition.top
done < ${tmpPath}/disk.topS
		