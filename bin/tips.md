## Check the metric from the source
```
/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh kafka.tools.JmxTool --object-name 'kafka.server:type=ReplicaManager,name=IsrShrinksPerSec" —jmx-url service:jmx:rmi:///jndi/rmi://my-server:9999/jmxrmi
1570716852211, 1225, shrinks, 4.2323164671607625E-135, 1.4821969375E-313, 0.0043640930279019545, 2.964393875E-314, SECONDS 
1570716854208, 1225, shrinks, 4.2088687906413127E-135, 1.4821969375E-313, 0.004364061978386349,  2.964393875E-314, SECONDS 
1570716856208, 1225, shrinks, 4.2088687906413127E-135, 1.4821969375E-313, 0.004364030876985068,  2.964393875E-314, SECONDS 
1570716858209, 1225, shrinks, 4.185551017813714E-135,  1.4821969375E-313, 0.004363999781351087,  2.964393875E-314, SECONDS  
```

## Timestamp d'un offset, par exemple la date de l'offset le plus ancien (latest) d'une partition d'un broker
``` /usr/hdp/current/kafka-broker/bin/kafka-run-class kafka.tools.DumpLogSegments --deep-iteration --print-data-log --files <my-log-file> | head -3 ```

