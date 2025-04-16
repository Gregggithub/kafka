from confluent_kafka import Consumer, TopicPartition
import time

# Configuration Kafka avec authentification SASL
conf = {
    'bootstrap.servers': 'broker1:9093,broker2:9093',
    'security.protocol': 'SASL_SSL',
    'sasl.mechanisms': 'PLAIN',  # ou 'SCRAM-SHA-512'
    'sasl.username': 'ton_user',
    'sasl.password': 'ton_mot_de_passe',
    'group.id': 'groupe-temporaire',
    'auto.offset.reset': 'latest',
    'enable.partition.eof': True
}

consumer = Consumer(conf)

topic = 'ton-topic'

# Récupérer la liste des partitions du topic
metadata = consumer.list_topics(topic, timeout=10.0)
partitions = metadata.topics[topic].partitions

for p_id in partitions:
    tp = TopicPartition(topic, p_id)

    # Aller à la fin de la partition
    consumer.assign([tp])
    consumer.seek(tp, offset=Consumer.OFFSET_END)
    time.sleep(0.5)  # pause pour laisser le temps au seek
    last_offset = consumer.position(tp)

    if last_offset == 0:
        print(f"[{topic}-{p_id}] Partition vide.")
        continue

    # Aller lire le dernier message
    tp.offset = last_offset - 1
    consumer.assign([tp])
    msg = consumer.poll(timeout=5.0)

    if msg is None or msg.error():
        print(f"[{topic}-{p_id}] Erreur ou pas de message.")
    else:
        offset = msg.offset()
        ts_type, timestamp = msg.timestamp()
        print(f"[{topic}-{p_id}] Dernier offset: {offset}, Timestamp: {timestamp}")

consumer.close()
