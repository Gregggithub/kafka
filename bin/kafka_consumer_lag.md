## Functionnality 
The program check_kafka_consumer_lag.sh permets de supveriser le lag des consumer group Kafka. 

Ce lag est calcule sur le principe suivant : écart entre le dernier offset ecrit (par le producer) et le dernier offset lu (par le consumer). Le but étant de remonter une alerte lors d'une defaillance du programme consommant les donnees dans un topic Kafka.

## How to use
### Print to help
```
./check_kafka_consumer_lag.sh -h 
DESCRIPTION
	Check the lag for a consumer group 
OPTIONS 
	--consumer		Mandatory		Name of the consumer group
	--lag			Mandatory		Max lag value
	--topic			Optional		Name of the topic. If not indicate, it will be all the topic
	--summary		Optional		Prompt a summary on one line
	--debug			Optional		Set debug (set -x)
```

### Description of each argument
#### consumer 
Mandatory, it's the name of the consumer group. When a program needs to read messages in a topic Kafka, a consumer group must be define. 
A consumer group can have one or n topics.

#### lag 
Mandatory, you need to define the correct lag value for your consumer. It depends to the design of the consumer program (batch size, streaming, time, etc). 
Note : lag value must be numeric.

#### topic 
Optional, you can set one or n topics with the space delimiter. If this parameter is not setting, all the topic belongs to the consumer group will be supervise. 

#### summary
Optional, print a summary on one line whatever the number of topic for a consumer group. 
If the option is no setting, the program print one line by topic.

#### debug
Optional, set the "set -x" in the program to help for the diagnostic. 

## How to use 
Let introduce an example :
- Name of the consumer group my-consumer-group
- Two topics in this consumer group : my-topic-2 (11 partitions) and my-topic-1 (16 partitions) 
- Lag setting 5000 

#### Check all the topic
```
./check_kafka_consumer_lag.sh --consumer my-consumer-group --lag 5000
OK : The consumer group my-consumer-group have 0 partitions (on 16) for the topic my-topic-1 with the lag parameter value 5000
OK : The consumer group my-consumer-group have 0 partitions (on 11) for the topic my-topic-2 with the lag parameter value 5000
```

#### Check all the topic with summary 
```
./checkkafka_consumer_lag.sh --consumer my-consumer-group --lag 5000 --summary
The consumer group my-consumer-group have 2 topic OK and 0 topic KO (0 partitions KO) for topic * with the lag parameter value 5000. 
```

#### Check one or two topics
```
./check_kafka_consumer_lag.sh --consumer my-consumer-group --lag 5000 --topic "my-topic-2"
OK The consumer group my-consumer-group have 0 partitions (on 11) for the topic my-topic-2 with the lag parameter value 5000
```
```
./check_kafka_consumer_lag.sh --consumer my-consumer-group --lag 5000 --topic "my-topic-2|my-topic-1"
OK The consumer group my-consumer-group have 0 partitions (on 16) for the topic my-topic-1 with the lag parameter value 5000
OK The consumer group my-consumer-group have 0 partitions (on 11) for the topic my-topic-2 with the lag parameter value 5000
```

## About the mecanism
The different steps to check the lag :
- Write in a temporary file the result of the consumer group 
- From the temp file, isolate each topic to find the lag for each partition 
- If a partition is stricly above the lag, some variables are incremented for the statistics and the return code will be 2 (variable RET)

### How list the consumer group 
```
sudo /usr/hdp/current/kafka-broker/bin/kafka-consumer-groups.sh --zookeeper <quorum:2181/kafka> --describe --group my-consumer-group
GROUP					TOPIC			PARTITION	CURRENT-OFFSET	LOG-END-OFFSET	LAG		OWNER
my-consumer-group		my-topic-1		0			19402588613		19402589319		706		my-consumer-group-server-fo_A-0
my-consumer-group		my-topic-1		1			19402002909		19402003620		711		my-consumer-group-server-fo_A-1
my-consumer-group		my-topic-1		2			19425717941		19425718652		711		my-consumer-group-server-fo_A-2
my-consumer-group		my-topic-1		3			19412497138		19412497851		713		my-consumer-group-server-fo_A-3
my-consumer-group		my-topic-1		4			12051463794		12051464509		715		my-consumer-group-server-fo_A-4
my-consumer-group		my-topic-2		0			13632589990		13632591269		1279	my-consumer-group-server-fo_B-0
my-consumer-group		my-topic-2		1			13637776254		13637777526		1272	my-consumer-group-server-fo_B-1
my-consumer-group		my-topic-2		2			13635584415		13635585691		1276	my-consumer-group-server-fo_B-2
my-consumer-group		my-topic-2		3			13624017082		13624018272		1190	my-consumer-group-server-fo_B-3
my-consumer-group		my-topic-2		4			5636710590		5636711879		1289	my-consumer-group-server-fo_B-4
```
We can find that all the topics (my-topic-1 and my-topic-2) belongs to the consumer group my-consumer-group with 4 informations :
- CURRENT-OFFSET : this is the last committed offset of the consumer instance
- LOG-END-OFFSET : it's the last offset commit and replicated of the partition (in fact, the last message write by the producer) 
- LAG: is the difference between the current consumer offset and the highest offset, hence how far behind the consumer is, 
- OWNER : is the client id 