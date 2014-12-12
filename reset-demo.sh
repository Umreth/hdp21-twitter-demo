echo "Stopping Storm topology"
storm kill Twittertopology

echo "Cleaning Tweets.xls"
rm -f /tmp/Tweets.xls

echo "Re-creating /tweets/staging HDFS dir"
sudo -u hdfs hadoop fs -rm -R /tweets
sudo -u hdfs hadoop fs -mkdir /tweets
sudo -u hdfs hadoop fs -chmod +rwx /tweets
sudo -u hdfs hadoop fs -mkdir /tweets/staging
sudo -u hdfs hadoop fs -chmod +rwx /tweets/staging

echo "Re-creating tweets hive tables"
hive -f /root/twitterdemo/stormtwitter-mvn/twitter.sql
hive -e 'drop table tweets_orc_partition_single;'

echo "Resetting Solr/Banana"
/root/twitterdemo/setup-scripts/restart_solr_banana.sh

echo "Re-creating alerts table in HBase"
/root/twitterdemo/fetchSecuritiesList/runcreatehbasetables.sh

