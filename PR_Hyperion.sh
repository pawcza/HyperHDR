#!/bin/bash
# Script for downloading a specific open Pull Request Artifact from Hyperion.NG on
# Raspbian/HyperBian/RasPlex/OSMC/RetroPie/LibreELEC/Lakka

# Fixed variables
api_url="https://api.github.com/repos/hyperion-project/hyperion.ng"
pr_token="a1ef79fcd73a28b893752e498296fb0d28d0f0e1"
type wget > /dev/null 2> /dev/null
hasWget=$?
type curl > /dev/null 2> /dev/null
hasCurl=$?

if [[ "${hasWget}" -ne 0 ]] && [[ "${hasCurl}" -ne 0 ]]; then
	echo '---> Critical Error: wget or curl required to download pull request artifacts'
	exit 1
fi

function request_call() {
	if [ $hasWget -eq 0 ]; then
		echo $(wget --quiet -O - $1)
	elif [ $hasCurl -eq 0 ]; then
		echo $(curl -skH "Authorization: token ${pr_token}" $1)
	fi
}

# Check for a command line argument (PR number)
if [ "$1" == "" ] || [ $# -gt 1 ]; then
	echo "Usage: $0 <PR_NUMBER>" >&2
	exit 1
else
	pr_number="$1"
fi

# Set welcome message
echo '*******************************************************************************'
echo 'This script will download a specific open Pull Request Artifact from Hyperion.NG'
echo 'Created by Paulchen-Panther - hyperion-project.org - the official Hyperion source.'
echo '*******************************************************************************'

# Find out which system we are on
OS_RASPBIAN=`grep -m1 -c 'Raspbian\|RetroPie' /etc/issue` # /home/pi
OS_HYPERBIAN=`grep ID /etc/os-release | grep -m1 -c HyperBian` # /home/pi
OS_RASPLEX=`grep -m1 -c RasPlex /etc/issue` # /storage/
OS_OSMC=`grep -m1 -c OSMC /etc/issue` # /home/osmc
OS_LIBREELEC=`grep -m1 -c LibreELEC /etc/issue` # /storage/
OS_LAKKA=`grep -m1 -c Lakka /etc/issue` # /storage

# Check that
if [ $OS_RASPBIAN -ne 1 ] && [ $OS_HYPERBIAN -ne 1 ] && [ $OS_RASPLEX -ne 1 ] && [ $OS_LIBREELEC -ne 1 ] && [ $OS_OSMC -ne 1 ] && [ $OS_LAKKA -ne 1 ]; then
	echo '---> Critical Error: We are not on Raspbian/HyperBian/RasPlex/OSMC/RetroPie/LibreELEC/Lakka -> abort'
	exit 1
fi

# Find out if we are on an Raspberry Pi or x86_64
CPU_RPI=`grep -m1 -c 'BCM2708\|BCM2709\|BCM2710\|BCM2835\|BCM2836\|BCM2837\|BCM2711' /proc/cpuinfo`
CPU_x86_64=`grep -m1 -c 'Intel\|AMD' /proc/cpuinfo`
# Check that
if [ $CPU_RPI -ne 1 ] && [ $CPU_x86_64 -ne 1 ]; then
	echo '---> Critical Error: We are not on an Raspberry Pi or an x86_64 CPU -> abort'
	exit 1
fi

# Check if RPi or x86_64
RPI_1_2_3_4=`grep -m1 -c 'BCM2708\|BCM2709\|BCM2710\|BCM2835\|BCM2836\|BCM2837\|BCM2711' /proc/cpuinfo`
Intel_AMD=`grep -m1 -c 'Intel\|AMD' /proc/cpuinfo`

# Select the architecture
if [ $RPI_1_2_3_4 -eq 1 ]; then
	arch_old="armv6hf"
	arch_new="armv6l"
elif [ $Intel_AMD -eq 1 ]; then
	arch_old="windows"
	arch_new="x68_64"
else
	echo "---> Critical Error: Target platform unknown -> abort"
	exit 1
fi

# Determine if PR number exists
pulls=$(request_call "$api_url/pulls")
pr_exists=$(echo "$pulls" | tr '\r\n' ' ' | python -c """
import json,sys
data = json.load(sys.stdin)

for i in data:
	if i['number'] == "$pr_number":
		print('exists')
		break
""" 2>/dev/null)

if [ "$pr_exists" != "exists" ]; then
	echo "---> Pull Request $pr_number not found -> abort"
	exit 1
fi

# Get head_sha value from 'pr_number'
head_sha=$(echo "$pulls" | tr '\r\n' ' ' | python -c """
import json,sys
data = json.load(sys.stdin)

for i in data:
	if i['number'] == "$pr_number":
		print(i['head']['sha'])
		break
""" 2>/dev/null)

if [ -z "$head_sha" ]; then
	echo "---> The specified PR #$pr_number has no longer any artifacts."
	echo "---> It may be older than 14 days. Ask the PR creator to recreate the artifacts at the following URL:"
	echo "---> https://github.com/hyperion-project/hyperion.ng/pull/$pr_number"
	exit 1
fi

# Determine run_id from head_sha
runs=$(request_call "$api_url/actions/runs")
run_id=$(echo "$runs" | tr '\r\n' ' ' | python -c """
import json,sys
data = json.load(sys.stdin)

for i in data['workflow_runs']:
	if i['head_sha'] == '"$head_sha"':
		print(i['id'])
		break
""" 2>/dev/null)

if [ -z "$run_id" ]; then
	echo "---> The specified PR #$pr_number has no longer any artifacts."
	echo "---> It may be older than 14 days. Ask the PR creator to recreate the artifacts at the following URL:"
	echo "---> https://github.com/hyperion-project/hyperion.ng/pull/$pr_number"
	exit 1
fi

# Get archive_download_url from workflow
artifacts=$(request_call "$api_url/actions/runs/$run_id/artifacts")
archive_download_url=$(echo "$artifacts" | tr '\r\n' ' ' | python -c """
import json,sys
data = json.load(sys.stdin)

for i in data['artifacts']:
	if i['name'] == '"$arch_old"' or i['name'] == '"$arch_new"':
		print(i['archive_download_url'])
		break
""" 2>/dev/null)

if [ -z "$archive_download_url" ]; then
	echo "---> The specified PR #$pr_number has no longer any artifacts."
	echo "---> It may be older than 14 days. Ask the PR creator to recreate the artifacts at the following URL:"
	echo "---> https://github.com/hyperion-project/hyperion.ng/pull/$pr_number"
	exit 1
fi

# Download packed PR artifact
echo "---> Downloading the Pull Request #$pr_number"
if [ $hasWget -eq 0 ]; then
	wget --quiet --header="Authorization: token ${pr_token}" -O $HOME/temp.zip $archive_download_url
elif [ $hasCurl -eq 0 ]; then
	curl -skH "Authorization: token $pr_token" -o $HOME/temp.zip -L --get $archive_download_url
fi

# Create new folder & extract PR artifact
echo "---> Extracting packed Artifact"
mkdir -p $HOME/hyperion_pr$pr_number
unzip -p $HOME/temp.zip | tar --strip-components=2 -C $HOME/hyperion_pr$pr_number share/hyperion/ -xz

# Delete PR artifact
echo '---> Remove temporary files'
rm $HOME/temp.zip 2>/dev/null

# Create the startup script
echo '---> Create startup script'
STARTUP_SCRIPT="#!/bin/sh

# Stop hyperion service if it is running
systemctl -q stop hyperion.service 2>/dev/null
systemctl -q stop hyperiond@pi.service 2>/dev/null

# Start PR artifact
exec $HOME/hyperion_pr$pr_number/bin/hyperiond -d -u $HOME/hyperion_pr$pr_number"

# systemctl required sudo on Raspbian/HyperBian/OSMC
if [ $OS_RASPBIAN -eq 1 ] || [ $OS_HYPERBIAN -eq 1 ] || [ $OS_OSMC -eq 1 ]; then
	STARTUP_SCRIPT=$(printf '%s\n' "$STARTUP_SCRIPT" | sed '4,5s/./sudo &/')
fi

# Place startup script
echo "$STARTUP_SCRIPT" >> $HOME/hyperion_pr$pr_number/$pr_number.sh

# Set the executen bit
chmod +x -R $HOME/hyperion_pr$pr_number/$pr_number.sh

# Install missing libraries on Raspbian/RetroPie/OSMC
if [ $OS_RASPBIAN -eq 1 ]; then
	echo '---> Install missing library libcec'
	sudo apt-get install libcec4 -y
elif [ $OS_OSMC -eq 1 ]; then
	echo '---> Install missing libraries libusb & libcec'
	sudo apt-get install libusb-1.0-0 -y
fi

# Check, if HDMI output forced (just for Raspbian/RaspiOS)
if [ $OS_RASPBIAN -eq 1 ]; then
	HDMIOK=`grep '^\hdmi_force_hotplug=1\|^\hdmi_drive=2' /boot/config.txt | wc -l`
	if [ $OS_RASPBIAN -ne 2 ]; then
		sudo sed -i "s/^#hdmi_force_hotplug=1.*/hdmi_force_hotplug=1/" /boot/config.txt
		sudo sed -i "s/^#hdmi_drive=2.*/hdmi_drive=2/" /boot/config.txt
		REBOOTMESSAGE="echo Please reboot, we inserted hdmi_force_hotplug=1 and hdmi_drive=2 to /boot/config.txt"
	fi
fi

echo "*******************************************************************************"
echo "Download finished!"
$REBOOTMESSAGE
echo "You can test it with this command: ~/hyperion_pr$pr_number/$pr_number.sh"
echo "Remove it with: rm -R ~/hyperion_pr$pr_number"
echo "Feedback is welcome at https://github.com/hyperion-project/hyperion.ng/pull/$pr_number"
echo "*******************************************************************************"
