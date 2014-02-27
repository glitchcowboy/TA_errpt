#!/usr/bin/ksh
if [ -d /opt/splunk ];then SPLUNK_HOME=/opt/splunk; else SPLUNK_HOME=/opt/splunkforwarder;fi
#echo "SPLUNK_HOME: $SPLUNK_HOME"
BDIR=$SPLUNK_HOME/etc/apps/TA_errpt
iam=`basename $0`
PIDFILE=$BDIR/$iam.pid
#echo "PIDFILE IS: $PIDFILE"
[ -d /var/log/errpt ] || { mkdir -p /var/log/errpt; }
ERPTLOG=/var/log/errpt/splunk_errpt.log

nice_stop()
{
	for pid in `ps -ef|grep -v grep|awk '/splunk_errpt/ {print $2}'`
	do
        	echo "Cleaning up old errpt processes: killing $pid"
        	/usr/bin/kill -9 $pid
	done
        [ -f $PIDFILE ] && { rm $PIDFILE; }
        date +%m%d%H%M%y > /tmp/splunk_errpt_lastrun
        exit 0
}

trap "nice_stop" INT TERM SIGHUP SIGINT SIGTERM

watch()
{
        echo "Refreshing PIDFILE"
        echo $$ > $PIDFILE
        echo "Setting lastrun"
        [ -f /tmp/splunk_errpt_lastrun ] && { lastrun=`cat /tmp/splunk_errpt_lastrun`; } || { lastrun=`date +%m%d%H%M%y`; }
	
	# Test to see if splunk_errpt link exists, else create it
	[ -h $BDIR/splunk_errpt ] || { ln -s /usr/bin/errpt $BDIR/splunk_errpt; }
        echo "starting $BDIR/splunk_errpt -ac -s $lastrun >> $ERPTLOG"
        exec $BDIR/splunk_errpt -ac -s $lastrun >> $ERPTLOG
        date +%m%d%H%M%y > /tmp/splunk_errpt_lastrun
        nice_stop

}

if [ -f $PIDFILE ];then
        OLDPID=`cat $PIDFILE`
        if [ `ps -ef|grep -v grep|grep -c $OLDPID` -gt 0 ] || [ `ps -ef|grep -v grep |grep -c "errpt.sh"` -gt 1 ]; then
                #echo "$iam Still running"
		exit 1
        else
                [ -f $PIDFILE ] && { rm $PIDFILE; }
		
		#splunkd tends to kill scripts with a -9 so errpt doesn't get whacked
		# Now I'm going to kill any remaining
		for pid in `ps -ef|grep -v grep|awk '/splunk_errpt/ {print $2}'`
		do
        		echo "Cleaning up old errpt processes: killing $pid"
        		/usr/bin/kill -9 $pid
		done

                watch
        fi
elif [ `ps -ef|grep -v grep|grep -c splunk_errpt` -gt 0 ]; then	
        for pid in `ps -ef|grep -v grep|awk '/splunk_errpt/ {print $2}'`
        do
                echo "Cleaning up old errpt processes: killing $pid"
                /usr/bin/kill -9 $pid
        done	
else
        watch
fi

