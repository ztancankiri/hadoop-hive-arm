#!/bin/sh

service ssh start
echo 'y' | /opt/hadoop/bin/hadoop namenode -format
/opt/hadoop/sbin/stop-all.sh
/opt/hadoop/sbin/start-all.sh
echo 'y' | /opt/hadoop/bin/hdfs namenode -format
/opt/hadoop/bin/hdfs dfs -mkdir /tmp
/opt/hadoop/bin/hdfs dfs -mkdir -p /user/hadoop
/opt/hadoop/bin/hdfs dfs -mkdir -p /user/hive/warehouse
/opt/hadoop/bin/hdfs dfs -chmod g+w /tmp
/opt/hadoop/bin/hdfs dfs -chmod g+w /user/hive/warehouse