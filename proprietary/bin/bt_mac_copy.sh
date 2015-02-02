#!/system/bin/sh

# Copyright (c) 2012-2013, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
brcm_wifilink=y
brcm_nfclink=y
cam_factory_copy=y

if [ -L /data/misc/wifi/firmware/fw_bcmdhd.bin ]; then
		brcm_wifilink=n
fi

if [ $brcm_wifilink = y ]; then
/system/bin/ln -s /system/vendor/firmware/bcm43341/fw_bcmdhd.bin /data/misc/wifi/firmware/fw_bcmdhd.bin
/system/bin/ln -s /system/vendor/firmware/bcm43341/fw_bcmdhd.bin /data/misc/wifi/firmware/fw_bcmdhd_apsta.bin
/system/bin/ln -s /system/vendor/firmware/bcm43341/fw_bcmdhd_a0.bin /data/misc/wifi/firmware/fw_bcmdhd_a0.bin
/system/bin/ln -s /system/vendor/firmware/bcm43341/fw_bcmdhd_a0.bin /data/misc/wifi/firmware/fw_bcmdhd_apsta_a0.bin
/system/bin/ln -s /system/vendor/firmware/bcm43341/fw_bcmdhd_mfgtest.bin /data/misc/wifi/firmware/fw_bcmdhd_mfgtest.bin
setprop wifi.driver_param_path "/sys/module/bcmdhd/parameters/firmware_path"
fi

if [ -L /data/nfc/libnfc-brcm.conf ]; then
		brcm_nfclink=n
fi

if [ $brcm_nfclink = y ]; then
/system/bin/ln -s /system/etc/libnfc-brcm-43341.conf /data/nfc/libnfc-brcm.conf
/system/bin/ln -s /system/etc/libnfc-brcm-43341b00.conf /data/nfc/libnfc-brcm-43341b00.conf
fi

echo 262144 > /proc/sys/net/core/wmem_default
echo 262144 > /proc/sys/net/core/wmem_max

rm /data/misc/bluetooth/bdaddr
rm /data/misc/wifi/firmware/nvram_43341_rev4.txt

/system/xbin/wifimacaddr

chmod 666 /data/misc/bluetooth/bdaddr
chmod 666 /data/misc/wifi/firmware/nvram_43341_rev4.txt
chown gps:system /data/gps/.gps.interface.pipe.to_gpsd
chown gps:system /data/gps/.gpsd.lock
chown gps:system /data/gps/glgpsctrl

if [ -L /data/factory.bin ]; then
		cam_factory_copy=n
fi

if [ $cam_factory_copy = y ]; then
cp /mnt/modem/data/factory/factory.bin /data/factory.bin
chmod 666 /data/factory.bin
fi

