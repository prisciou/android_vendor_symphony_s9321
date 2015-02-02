#!/system/bin/sh
# Copyright (c) 2013, NVIDIA CORPORATION.  All rights reserved.

# For Icera single flash modem, this script builds dynamically content of platform config file
#  transmitted to BB at boot by fil-daemon.

##################
# Some constants #
##################
LOGCAT_TAG="MDMBOOTCFG"
PLATFORM_CONFIG_FILE="/data/rfs/data/factory/platformConfig.xml"
RFM_CONFIG_FILE="/data/rfs/data/factory/rfmConfig.xml"
CALIBRATION_FILE="/data/rfs/data/factory/calibration_0.bin"
PMIC_SYSFS_ENTRY="/sys/kernel/pmic/dvfs_data"
SOC_SYSFS_ENTRY="/sys/devices/soc0/soc_id"

##################
# Some functions #
##################
ALOGI() {
    /system/bin/log -p i -t ${LOGCAT_TAG} "$1"
}

ALOGE() {
    /system/bin/log -p e -t ${LOGCAT_TAG} "$1"
}

ALOGD() {
    /system/bin/log -p d -t ${LOGCAT_TAG} "$1"
}

# Read a line using ">" to split content
read_xml () {
    # change Input Field Separator to be ">"
    local IFS=\>
    # read until "<" and split using new local IFS: split put in TAG and VALUE
    read -d \< TAG VALUE
}

# Extract value from <tag>value</tag> reading a file:
# $1 to be the input file
# $2 to be the tag whose value is required
# echo "" or "value" if found.
get_xml_tag_value() {
    input=$1
    tag=$2
    value=""
    while read_xml; do
        if [[ ${TAG} = ${tag} ]]; then
            value=${VALUE}
            break
        fi
    done < ${input}
    echo "${value}"
}

# Read PMIC_SYSFS_ENTRY to extract value for
# explicit setting
#
# $1 to be the setting to extract
read_pmic_setting() {
    local IFS=:
    while read setting value; do
        if [ "$1" == "${setting}" ]; then
            echo "${value}"
        fi
    done < ${PMIC_SYSFS_ENTRY}
}

####################
# Main script code #
####################

if [ $(getprop ro.boot.modem) != "icera" ]; then
    # only applicable if icera modem activated
    exit 1
fi

# Default platform config values
HW_PLAT=""
BB_PLAT=""
RF_PLAT=""
VCORE_BASE=""
VCORE_STEP=""
VCORE_MAX=""
VCORE_DEFAULT=""
SOC_REV=""
SOC_SKU=""
SOC_PID=""

TMP_FILE="/data/rfs/data/factory/boot_tmp_calibration_0.bin"
if [ -f ${CALIBRATION_FILE} ]; then
    # Keep a copy of existing cal data:
    cp ${CALIBRATION_FILE} ${TMP_FILE}
fi

# Get cal data and RFM config from EEPROM:
#/system/bin/icera-rfm-eeprom -d /dev/i2c-1 -r --cal ${CALIBRATION_FILE} --rfm ${RFM_CONFIG_FILE}

# Diff previous and new cal data:
if [ -f ${TMP_FILE} ]; then
    if ! cmp ${CALIBRATION_FILE} ${TMP_FILE};then
        # mismatch: new cal data
        ALOGI "$0: Calibration data differs after read in EEPROM."
        RESTART_FOR_NEW_CAL="yes"
    fi
    rm ${TMP_FILE}
else
    if [ -f ${CALIBRATION_FILE} ]; then
        # ${CALIBRATION_FILE} created with last call to icera-rfm-eeprom
        ALOGI "$0: New calibration data extracted from EEPROM."
        RESTART_FOR_NEW_CAL="yes"
    fi
fi

# Check RFM_CONFIG_FILE exists and extract <rfPlat> value if found
if [ -f ${RFM_CONFIG_FILE} ]; then
    RF_PLAT=`get_xml_tag_value ${RFM_CONFIG_FILE} "rfPlat"`
fi

# Check PLATFORM_CONFIG_FILE exists and extract XML tags values
#  to be put in new PLATFORM_CONFIG_FILE (if required) and transmitted to BB.
#
# If no PLATFORM_CONFIG_FILE found exit: on T148, for backward compatibility, we cannot
#  start without platformConfig file with at least <hwplat> indication.
#
if [ ! -f ${PLATFORM_CONFIG_FILE} ]; then
    exit 1
fi

HW_PLAT=`get_xml_tag_value ${PLATFORM_CONFIG_FILE} "hwPlat"`
BB_PLAT=`get_xml_tag_value ${PLATFORM_CONFIG_FILE} "bbPlat"`
VCORE_BASE=`get_xml_tag_value ${PLATFORM_CONFIG_FILE} "vcoreBase"`
VCORE_STEP=`get_xml_tag_value ${PLATFORM_CONFIG_FILE} "vcoreStep"`
VCORE_MAX=`get_xml_tag_value ${PLATFORM_CONFIG_FILE} "vcoreMax"`
VCORE_DEFAULT=`get_xml_tag_value ${PLATFORM_CONFIG_FILE} "vcoreDefault"`
if [ -z "${RF_PLAT}" ]; then
    # no valid RFM_CONFIG_FILE: transmit one from PLATFORM_CONFIG_FILE
    RF_PLAT=`get_xml_tag_value ${PLATFORM_CONFIG_FILE} "rfPlat"`
fi
if [ -z "${BB_PLAT}" ]; then
    # no <bbPlat>: transmits only <hwPlat> so remove rfPlat if found previously
    RF_PLAT=""
fi

# Get AP PMIC settings to populate <vcoreBase> and <vcoreStep>
if [ -f ${PMIC_SYSFS_ENTRY} ]; then
    VCORE_BASE=`read_pmic_setting base_voltage`
    VCORE_STEP=`read_pmic_setting step_size`
    VCORE_MAX=`read_pmic_setting max_voltage`
    VCORE_DEFAULT=`read_pmic_setting default_voltage`
fi

# Get SOC infos from sysfs with following format:
# REV=A1:SKU=0x1f:PID=0x0
if [ -f ${SOC_SYSFS_ENTRY} ]; then
    soc_ids=`cat ${SOC_SYSFS_ENTRY}`
    tmp=${soc_ids#*REV=}
    SOC_REV=${tmp%%:*}
    tmp=${soc_ids#*SKU=}
    SOC_SKU=${tmp%%:*}
    tmp=${soc_ids#*PID=}
    SOC_PID=${tmp%%:*}
fi

# Build some tmp platform config file:
TMP_FILE="/data/rfs/data/factory/tmp_platformConfig.xml"
echo "<PlatformConfig>" > ${TMP_FILE}
if [ -n "${HW_PLAT}" ]; then
    echo " <hwPlat>${HW_PLAT}</hwPlat>" >> ${TMP_FILE}
fi
if [ -n "${BB_PLAT}" ]; then
    echo " <bbPlat>${BB_PLAT}</bbPlat>" >> ${TMP_FILE}
fi
if [ -n "${RF_PLAT}" ]; then
    echo " <rfPlat>${RF_PLAT}</rfPlat>" >> ${TMP_FILE}
fi
if [ -n "${VCORE_BASE}" ]; then
    echo " <vcoreBase>${VCORE_BASE}</vcoreBase>" >> ${TMP_FILE}
fi
if [ -n "${VCORE_STEP}" ]; then
    echo " <vcoreStep>${VCORE_STEP}</vcoreStep>" >> ${TMP_FILE}
fi
if [ -n "${VCORE_MAX}" ]; then
    echo " <vcoreMax>${VCORE_MAX}</vcoreMax>" >> ${TMP_FILE}
fi
if [ -n "${VCORE_DEFAULT}" ]; then
    echo " <vcoreDefault>${VCORE_DEFAULT}</vcoreDefault>" >> ${TMP_FILE}
fi
if [ -n "${SOC_REV}" ]; then
    echo " <socRev>${SOC_REV}</socRev>" >> ${TMP_FILE}
fi
if [ -n "${SOC_SKU}" ]; then
    echo " <socSku>${SOC_SKU}</socSku>" >> ${TMP_FILE}
fi
if [ -n "${SOC_PID}" ]; then
    echo " <socPid>${SOC_PID}</socPid>" >> ${TMP_FILE}
fi
echo "</PlatformConfig>" >> ${TMP_FILE}

# Remove created RFM config file now useless...
rm -f ${RFM_CONFIG_FILE}

# Check if tmp file differs from existing one
if cmp ${PLATFORM_CONFIG_FILE} ${TMP_FILE};then
    # no mismatch: remove TMP_FILE
    rm ${TMP_FILE}
else
    # mismatch: need to replace current with tmp...
    ALOGI "$0: Platform config change detected."
    mv ${TMP_FILE} ${PLATFORM_CONFIG_FILE}
    chmod 666 ${PLATFORM_CONFIG_FILE}
    RESTART_FOR_NEW_CFG="yes"
fi

if [ -n "${RESTART_FOR_NEW_CAL}" -o -n "${RESTART_FOR_NEW_CFG}" ]; then
    ALOGI "$0: Restarting FILD."
    stop fil-daemon
    start fil-daemon
fi
