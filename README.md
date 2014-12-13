## Streaming workshop demo

#### Monitor Twitter stream for S&P 500 companies to identify & act on unexpected increases in tweet volume

1. Ingest: 
Listen for Twitter streams related to S&P 500 companies 
2. Processing:
  - Monitor tweets for unexpected volume
  - Volume thresholds managed in HBASE
3. Persistence:
  - HBase & HDFS & Solr
4. Refine:
  -  Update threshold values based on historical analysis of tweet volumes


##### Setup demo

These setup steps are only needed first time

- Download HDP 2.1 sandbox VM image (Hortonworks_Sandbox_2.1.ova) from [Hortonworks website](http://hortonworks.com/products/hortonworks-sandbox/)
- Import Hortonworks_Sandbox_2.1.ova into VMWare and configure its memory size to be at least 8GB RAM 
- Find the IP address of the VM and add an entry into your machines hosts file e.g.
```
192.168.191.241 sandbox.hortonworks.com sandbox    
```
- Connect to the VM via SSH (password hadoop)
```
ssh root@sandbox.hortonworks.com
```
- Pull latest code/scripts
```
git clone https://github.com/abajwa-hw/hdp21-twitter-demo.git	
```
- This starts Ambari/HBase and installs maven, kafka, solr, banana, phoenix-may take 10 min
```
/root/hdp21-twitter-demo/setup-demo.sh
source ~/.bashrc
```
- Open Ambari (http://sandbox.hortonworks.com:8080) and make below changes under HBase>config and then restart HBase
``` 
zookeeper.znode.parent=/hbase
hbase.regionserver.wal.codec=org.apache.hadoop.hbase.regionserver.wal.IndexedWALEditCodec
```
- Start storm via Ambari
- Twitter4J requires you to have a Twitter account and obtain developer keys by registering an "app". Create a Twitter account and app and get your consumer key/token and access keys/tokens:
https://apps.twitter.com > sign in > create new app > fill anything > create access tokens
- Then enter the 4 values into the file below in the sandbox
```
vi /root/hdp21-twitter-demo/kafkaproducer/twitter4j.properties
oauth.consumerKey=
oauth.consumerSecret=
oauth.accessToken=
oauth.accessTokenSecret=
```


##### Kafka basics - (optional)

```
#check if kafka already started
ps -ef | grep kafka

#if not, start kafka
nohup /opt/kafka/latest/bin/kafka-server-start.sh /opt/kafka/latest/config/server.properties &

#create topic
/opt/kafka/latest/bin/kafka-topics.sh --create --zookeeper sandbox.hortonworks.com:2181 --replication-factor 1 --partitions 1 --topic test

#list topic
/opt/kafka/latest/bin/kafka-topics.sh --zookeeper sandbox.hortonworks.com:2181 --list | grep test

#start a producer and enter text on few lines
/opt/kafka/latest/bin/kafka-console-producer.sh --broker-list sandbox.hortonworks.com:9092 --topic test

#start a consumer in a new terminal your text appears in the consumer
/opt/kafka/latest/bin/kafka-console-consumer.sh --zookeeper sandbox.hortonworks.com:2181 --topic test --from-beginning

#delete topic
/opt/kafka/latest/bin/kafka-run-class.sh kafka.admin.DeleteTopicCommand --zookeeper sandbox.hortonworks.com:2181 --topic test
```

#####  Run Twitter demo

- Review the list of stock symbols whose Twitter mentiones we will be tracking
http://en.wikipedia.org/wiki/List_of_S%26P_500_companies

- Generate securities csv from above page and review the securities.csv generated. The last field is the generated tweet volume threshold 
```
/root/hdp21-twitter-demo/fetchSecuritiesList/rungeneratecsv.sh
vi /root/hdp21-twitter-demo/fetchSecuritiesList/securities.csv
```

- Optional step for future runs: can add your other stocks/trending topics to csv to speed up tweets (no trailing spaces). Find these at http://mobile.twitter.com/trends
```
sed -i '1i$HDP,Hortonworks,Technology,Technology,Santa Clara CA,0000000001,5' /root/hdp21-twitter-demo/fetchSecuritiesList/securities.csv
sed -i '1i#mtvstars,MTV Stars,Entertainment,Entertainment,Hollywood CA,0000000001,40' /root/hdp21-twitter-demo/fetchSecuritiesList/securities.csv
```

- Open connection to HBase via Phoenix and check you can list tables
```
/root/phoenix-4.1.0-bin/hadoop2/bin/sqlline.py  sandbox.hortonworks.com:2181:/hbase
!tables
!q
```

- Make sure HBase is up via Ambari and create Hbase table using csv data with placeholder tweet volume thresholds
```
/root/hdp21-twitter-demo/fetchSecuritiesList/runcreatehbasetables.sh
```

- notice securities data was imported and alerts table is empty
```
/root/phoenix-4.1.0-bin/hadoop2/bin/sqlline.py  sandbox.hortonworks.com:2181:/hbase
select * from securities;
select * from alerts;
!q
```

- create Hive table where we will store the tweets for later analysis
```
hive -f /root/hdp21-twitter-demo/stormtwitter-mvn/twitter.sql
```

- Ensure Storm is started and then start storm topology to generate alerts into an HBase table for stocks whose tweet volume is higher than threshold this will also read tweets into Hive/HDFS/local disk/Solr/Banana. The first time you run below, maven will take 15min to download dependent jars
```
cd /root/hdp21-twitter-demo/stormtwitter-mvn
./runtopology.sh
```

- Other modes the topology could be started in future runs if you want to clean the setup or run locally (not on the storm running on the sandbox)
```
./runtopology.sh runOnCluster clean
./runtopology.sh runLocally skipclean
```

- open storm UI and confirm topology was created
http://sandbox.hortonworks.com:8744/

- In a new terminal, compile and run kafka producer to generate tweets containing first 400 stock symbols values from csv
```
/root/hdp21-twitter-demo/kafkaproducer/runkafkaproducer.sh
```

##### Observe results



- Open storm UI and drill into it to view statistics for each Bolt, 
'Acked' columns should start increasing
http://sandbox.hortonworks.com:8744/

- Open HDFS via Hue and see the tweets getting stored (note not all tweets have long/lat):
http://sandbox.hortonworks.com:8000/filebrowser/#/tweets/staging

- Open Hive table via Hue. Notice tweets are being streamed to Hive table that was created:
http://sandbox.hortonworks.com:8000/beeswax/table/default/tweets_text_partition

![Image](../master/screenshots/Hue-text-screenshot.png?raw=true)

- Open Banana UI and view/search tweet summary and alerts:
http://sandbox.hortonworks.com:8983/banana

![Image](../master/screenshots/Banana-screenshot.png?raw=true)

 
- Run a query in Solr to look at tweets/hashtags/alerts
http://sandbox.hortonworks.com:8983/solr/#/tweets
e.g. doctype_s:tweet or text_t:AAPL

- Open connection to HBase via Phoenix and notice alerts were generated
```
/root/phoenix-4.1.0-bin/hadoop2/bin/sqlline.py  sandbox.hortonworks.com:2181:/hbase
select * from alerts
```

- Notice tweets written to sandbox filesystem via FileSystem bolt
```
vi /tmp/Tweets.xls
```

###### To stop collecting tweets:

- kill the storm topology to stop processing tweets
```
storm kill Twittertopology
```
- To stop producing tweets, press Control-C in the terminal you ran runkafkaproducer.sh 


##### Import data to BI Tool via ODBC for analysis - optional

- Create ORC table and copy the tweets over:
```
hive -f /root/hdp21-twitter-demo/stormtwitter-mvn/createORC.sql
```

- View the contents of the ORC table created:
http://sandbox.hortonworks.com:8000/beeswax/table/default/tweets_orc_partition_single

- Grant select access to user hive to the ORC table 
```
hive -e 'grant SELECT on table tweets_orc_partition_single to user hive'
```
- On windows VM create an ODBC connector with below settings: 
```
	Host=<IP address of sandbox VM>
	port=10000 
	database=default 
	Hive Server type=Hive Server 2 
	Mechanism=User Name 
	UserName=hive 
```

- Import data from tweets_orc_partition_single table over ODBC and create some visualizations using PowerCharts




##### Other usage: Analyze any kind of tweet - optional


- Instead of filtering on tweets from certain stocks/hashtags, you can also consume all 
tweets returned by TwitterStream API and re-run runkafkaproducer.sh
Note that in this mode a large volume of tweets is generated so you should stop the kafka 
producer after 20-30s to avoid overloading the system
It also may take a few minutes after stopping the kafka producer before all the tweets 
show up in Banana/Hive
```
mv /root/hdp21-twitter-demo/fetchSecuritiesList/securities.csv /root/hdp21-twitter-demo/fetchSecuritiesList/securities.csv.bak
```

- To filter tweets based on geography open below file and uncomment out the line starting 
"tweetFilterQuery.locations" and re-run runkafkaproducer.sh
```
/root/hdp21-twitter-demo/kafkaproducer/TestProducer.java
```

##### Reset demo

- This empties out the demo related HDFS folders, Hive table, Solr core, Banana webapp
and stops the storm topoogy
```
/root/hdp21-twitter-demo/reset-demo.sh
```

- If kafka keeps sending your topology old tweets, you can also clear kafka queue
```
zookeeper-client
rmr /group1
```