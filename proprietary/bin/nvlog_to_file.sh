#!/system/bin/sh

compresslog=1
autolocate=1
LOGDIR=/data/local/logs
LNU=5
KROTNUM=17
KROTSIZE=512k
tosdcard=0

function getkernelrotatenum()
{
    kernelrotatenum=$(getprop persist.sys.log.rotatenum_k)
    if [ ! -z $kernelrotatenum ] ; then
        echo $kernelrotatenum
    else
        kernelrotatenum=$(getprop persist.sys.log.rotatenum)
        if [ ! -z $kernelrotatenum ] ; then
            echo $kernelrotatenum
        fi
    fi
}

function getkernelrotatesize()
{
    kernelrotatesize=$(getprop persist.sys.log.rotatesize_k)
    if [ ! -z $kernelrotatesize ] ; then
        echo $kernelrotatesize
    else
        kernelrotatesize=$(getprop persist.sys.log.rotatesize)
        if [ ! -z $kernelrotatesize ] ; then
            echo $kernelrotatesize
        fi
    fi
}

function prepare()
{
    echo prepare start
    
    #get log location, if sdcard exists, it has priority
    autolocate_tmp=$(getprop persist.sys.log.autolocate)
    if [ ! -z $autolocate_tmp ] ; then
    autolocate=$autolocate_tmp
    fi
    echo autolocate=$autolocate
    if [ $autolocate -eq 1 ] ; then
        mkdir /mnt/log/nvidia
        chmod 777 /mnt/log/nvidia
        mkdir /mnt/log/nvidia/logs
        chmod 777 /mnt/log/nvidia/logs
    	if [ -d /mnt/log/nvidia/logs ] ; then
            LOGDIR=/mnt/log/nvidia/logs
            tosdcard=1
#        else
#			mkdir /storage/sdcard0/nvidia
#       	chmod 777 storage/sdcard0/nvidia
#    	  	mkdir /storage/sdcard0/nvidia/logs
#   	  	chmod 777 /storage/sdcard0/nvidia/logs
#			if [ -d /storage/sdcard0/nvidia/logs ] ; then
#    		   	LOGDIR=/storage/sdcard0/nvidia/logs
#   		   	tosdcard=1
# 		    fi
        fi
    fi
    echo LOGDIR=$LOGDIR

    mode_tmp=$(getprop persist.sys.log.mode)
    if [ ! -z $mode_tmp ] ; then
        echo $mode_tmp
    else
        mode_tmp=smart
    fi

    if [ "$mode_tmp" == "simple" ] ; then
        compresslog=0
    elif [ "$mode_tmp" == "smart" ] ; then
        if [ tosdcard -eq 1 ] ; then
            compresslog=1    
        else
            compresslog=0
        fi
    else
        compresslog=1
    fi
    
    echo compresslog=$compresslog
	
	
    #previous boot logs count
    LNU_tmp=$(getprop persist.sys.log.prebootcnt)
    if [ ! -z $LNU_tmp ] ; then
    LNU=$LNU_tmp
    fi
    echo LNU=$LNU
    
    #kernel logs max rotating number
    KROTNUM_tmp=$(getkernelrotatenum)
    if [ ! -z $KROTNUM_tmp ] ; then
    KROTNUM=$KROTNUM_tmp
    fi
    echo KROTNUM=$KROTNUM
    
    #kernel log(*.log) max rotating size
    KROTSIZE_tmp=$(getkernelrotatesize)
    if [ ! -z $KROTSIZE_tmp ] ; then
    KROTSIZE=$KROTSIZE_tmp
    fi
    echo KROTSIZE=$KROTSIZE
    
    
    mkdir $LOGDIR
    chmod 777 $LOGDIR
    mkdir $LOGDIR/kernel
    mkdir $LOGDIR/temperature
    mkdir $LOGDIR/logcat
    chmod 777 $LOGDIR/*
    
    cd $LOGDIR
    
    for i in $(busybox seq 2 $LNU)
    do
        mv loglast$(($LNU-$i+1)).tar.gz loglast$(($LNU-$i+2)).tar.gz
    done
    
    if [ -f kernel/kernel.log -o -f logcat/logcat_main.log ] ; then
        echo "There are logs, package them!"
        cat /proc/last_kmsg > last_kmsg.log 
        busybox tar -cf loglast1.tar kernel/* logcat/* last_kmsg.log
        gzip loglast1.tar
        chmod 777 *
    else
        echo "There is no log!"
    fi
    
    rm logcat/*
    rm kernel/*
    rm last_kmsg.log
    
    # setprop log.log.filelog 1
    stop logcat_main
    stop logcat_radio
    stop logcat_system
    stop logcat_events
    
    start logcat_main
    start logcat_radio
    start logcat_system
    start logcat_events
    echo prepare end
}

function checksdcard()
{
    tmp=0
    if [ $autolocate -eq 1 ] ; then
        mkdir /mnt/log/nvidia/logs
        chmod 777 /mnt/log/nvidia/logs
        if [ -d /mnt/log/nvidia/logs ] ; then
            tmp=1
#        else
#        	mkdir /storage/sdcard0/nvidia/logs
#        	chmod 777 /storage/sdcard0/nvidia/logs
#        	if [ -d /storage/sdcard0/nvidia/logs ] ; then
#            	tmp=1
#            fi
        fi
    fi
	
    echo tmp=$tmp, tosdcard=$tosdcard
	
    if [ $tmp -ne $tosdcard ] ; then
        tosdcard=$tmp
        prepare
    fi
}

prepare

while true
do

checksdcard

cd $LOGDIR/kernel
if busybox test -f kernel.log ; then
    echo "kernel.log exist, append log to it!"
    dmesg -c >> kernel.log
    
    busybox find kernel.log -size +$KROTSIZE | busybox grep kernel.log
    if busybox test $? -eq 0 ; then
        echo "Rotate kernel logs!"
        for i in $(busybox seq 2 $KROTNUM)
        do
        	mv kernel$(($KROTNUM-$i+1)).log kernel$(($KROTNUM-$i+2)).log
        done
        mv kernel.log kernel1.log

        #if simple mode isn't set, we need compress the logs.
        if [ $compresslog -eq 1 ] ; then
            if busybox test -f kernel$KROTNUM.log ; then
                echo "kernel has arrived at max count, package them!"
                if [ -f kernel.log.tar.gz ] ; then
                    mv kernel.log.tar.gz kernel.log.old.tar.gz
                fi
                busybox tar -cf kernel.log.tar *
                
                gzip kernel.log.tar
                chmod 777 kernel.log.tar.gz
                rm kernel*.log
                rm kernel.log.old.tar.gz
            fi
        fi

        echo "" > kernel.log
        chmod 777 kernel.log
    fi    
else
    echo "kernel.log doesn't exist, create it!"
    dmesg -c > kernel.log
    chmod 777 kernel.log
fi

# 	cd $LOGDIR/temperature
#	if busybox test -f temperature.log ; then
#	    echo "temperature.log exist, append log to it!"
#	    date >> temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone0/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone1/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone2/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone3/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone4/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone5/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone6/temp >>temperature.log
#	    chmod 777 temperature.log

#	    busybox find temperature.log -size +$KROTSIZE | busybox grep temperature.log
#	    if busybox test $? -eq 0 ; then
#	        echo "Rotate temperature logs!"
#	        for i in $(busybox seq 2 $KROTNUM)
#	        do
#	        	mv temperature$(($KROTNUM-$i+1)).log temperature$(($KROTNUM-$i+2)).log
#	        done
#	        mv temperature.log temperature1.log
#	    fi

#	else
#	    echo "temperature.log doesn't exist, create it!"
#	    date > temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone0/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone1/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone2/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone3/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone4/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone5/temp >>temperature.log
#	    cat /sys/devices/virtual/thermal/thermal_zone6/temp >>temperature.log
#	    chmod 777 temperature.log
#	fi
#backup tombstones
cd $LOGDIR/logcat
ls /data/tombstones/*
if busybox test $? -eq 0 ; then
    echo "There are tombstones logs, package them!"
    mv /data/tombstones tombstones
    if busybox test -f tombstones.tar.gz ; then
        echo "tombstones.tar.gz exists!"
    	mv tombstones.tar.gz tombstones.old.tar.gz
        busybox tar -cf tombstones.tar tombstones/* tombstones.old.tar.gz
    else
        echo "tombstones.tar.gz doesn't exist!"
        busybox tar -cf tombstones.tar tombstones/*
    fi
    gzip tombstones.tar
    rm tombstones.old.tar.gz
    rm -r tombstones
else
    echo "There are no tombstones logs!"
fi


sleep 2

done
