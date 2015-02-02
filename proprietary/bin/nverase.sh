#!/system/bin/sh

DIR=/data/rfs/data/modem/
LOG=/system/bin/log
TAG=NVERASE
RM=/system/bin/rm

for i in `ls $DIR`
do
	f=$DIR$i
	$LOG -t $TAG "Erasing file $f"	
	$RM $f
done

sync
sleep 5
reboot




