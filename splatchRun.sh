#!/bin/bash


#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	SplatchTuesday.2020.12.30
#
# SYNOPSIS - How to use
#	
# 1) Script is called from JAMF policy. Script will referce local property list and execute accordingly.
# 2) Configure the app attributes to be included in this month's patching
# 3) Build associated app smart group and app policy
# 4) Build master policy with scope (e.g. IT lab, US computers) and reference this policy
# 
# 
####################################################################################################
#
# HISTORY
#
#	Version: 1.0
#
#	- Created by Scott Morabito, TechTonic LLC scott@ttonic.com 
#
####################################################################################################





### Initialize the arrays so any slot can be used, 20 slots are available
### Do not modify
update_trigger=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
#update_pkgkeyword=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
update_pkgkeyword=(qrst qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3 qrst3)
update_name=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
update_process=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
update_bundleID=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
###
###


##### Update these Attributes


# trigger needs to match exact name in JAMF
# pkgkeyword is case sensitive and is used to match presense of cached file
# name is used to display to users for information purposes
# process is the system process name used to check for running application
# bundleID is used to quit the app.  For example "mdls -name kMDItemCFBundleIdentifier /Applications/Slack.app/" = com.tinyspeck.slackmacgap

update_trigger[0]="PatchPolicyCache.Chrome.2020.01"
update_pkgkeyword[0]="Chrome"
update_name[0]="Google Chrome"
update_process[0]="Google Chrome"
update_bundleID[0]="com.google.Chrome"

update_trigger[1]="PatchPolicyCache.Slack.2020.01"
update_pkgkeyword[1]="Slack"
update_name[1]="Slack"
update_process[1]="Slack"
update_bundleID[1]="com.tinyspeck.slackmacgap"

update_trigger[2]="PatchPolicyCache.Firefox.2020.01"
update_pkgkeyword[2]="Firefox"
update_name[2]="Firefox"
update_process[2]="firefox"
update_bundleID[2]="org.mozilla.firefox"

#after this date
forceDateDisplay="01/02/24"

#use www.epochconverter.com
forceDateEpoch=1734929358
#2024 is 1734929358
#1608529847

#Custom trigger to match master policy.  Alphanumeric characters only. 
policy_name_for_record="2021.01v1" 

#local property list to store update status
SettingPLIST="/Library/Application Support/Splatch/com.splatch.softwareUpdateSettings.plist"


###### DO NOT UPDATE BELOW THIS LINE
###### DO NOT UPDATE BELOW THIS LINE
###### DO NOT UPDATE BELOW THIS LINE
###### DO NOT UPDATE BELOW THIS LINE
###### DO NOT UPDATE BELOW THIS LINE


###### Envrironment Variables
WaitRoomDir="/Library/Application Support/JAMF/Waiting Room/"
JamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
#icon_folder="/Applications/App Store.app/Contents/Resources/AppIcon.icns"
icon_folder="/Library/Application Support/JAMF/bin/Management Action.app/Contents/Resources/Self Service.icns"
icon_size=150
Contents=$( find "$WaitRoomDir" -maxdepth 1 -iname *.pkg -or -iname *.mpkg -or -iname *.dmg | awk -F"/" '{print $NF }' )
JAMFBIN=$(/usr/bin/which jamf)
CURRENTUSER=$(python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

function logEntry ()
{
	stamp=$(date)
#	echo "$stamp: $1" >> "/Library/Application Support/ttonic/update.log"
}


##find array location since bash does not have dimentioal arrays
function get_index()
{
	value=$1
	x=0
	for i in "${!update_pkgkeyword[@]}"; do
		if [[ "${update_pkgkeyword[$x]}" = "${value}" ]]; then
			echo "${i}";
		fi
		let x=$((x+1))
	done
}

	###some things we can do with above get_index
	#location=$(get_index "Slack")	
	#echo "Location of Slack is $location"	
	#echo "My trigger name is: ${update_trigger[ $location ]}"

##creates array of array indexes that are cached
function createCachedList()
{
	Contents=$( find "$WaitRoomDir" -maxdepth 1 -iname *.pkg -or -iname *.mpkg -or -iname *.dmg | awk -F"/" '{print $NF }' )

	#build an array of indexes needed based on cached contents
	cachedListIndex=()
	x=0
	for title in "${update_pkgkeyword[@]}"
		do
			#echo "looking for $title"
			if [[ "$Contents" == *"$title"* ]]; then
				location=$(get_index "$title")
				cachedListIndex+=("$location")
				let x=$((x+1))
			else
				#echo "not there"
				whatever=5
				#return 1
			fi
	done
}

function createAppRays()
{
	cachedTriggerList=()
	cachedKeywordList=()
	cachedNameList=()
	cachedProcessList=()
	cachedBundleID=()
	x=0	
	for node in "${cachedListIndex[@]}"	
	do
		
		#cachedTriggerList+=("${update_trigger[$x]}") #not used
		cachedKeywordList+=("${update_pkgkeyword[$node]}")
		cachedNameList+=("${update_name[$node]}")
		cachedProcessList+=("${update_process[$node]}")
		cachedBundleID+=("${update_bundleID[$node]}")
		let x=$((x+1))
	done
}


function pythonQuit()
{
	myBundle=$1
	export bundleID=$(echo $myBundle)
	
cat << EOF > pyscript.py
#!/usr/bin/python
from Cocoa import NSRunningApplication
import sys
import subprocess
import os
import time
APPLISTB = os.getenv('bundleID')
APPLIST = APPLISTB.split(",")

def check_if_running(bid):
	"""Test to see if an app is running by bundle ID"""
	# macOS API to check if an app bundle is running or not
	app = NSRunningApplication.runningApplicationsWithBundleIdentifier_(bid)
	# return True if running, False if not
	if app:
		return True
	if not app:
		return False

def quit_application(bid):
	"""quits apps using NSRunningApplication"""
	# use API to assign a variable for the running API so we can terminate it
	apps = NSRunningApplication.runningApplicationsWithBundleIdentifier_(bid)
	# API returns an array always, must iterate through it
	for app in apps:
		# terminate the app
		app.terminate()
		# if the app does not terminate in 3 seconds gracefully force it
		time.sleep(3)
		if not app.isTerminated():
			app.forceTerminate()

def run():
	for app in APPLIST:
		if not check_if_running(app):
			print("app not running")
			# run_update_policy(UPDATEPOLICY)
			sys.exit(0)
	# check to see if we are forcing the app to quit first, and take action
		# use the bundle ID or IDs from parameter 4 and iterate through them
	for bid in APPLIST:
		print("go through app list")
		# check if the app is running by bundle ID and we are choosing to prompt from parameter 5	
		quit_application(bid)
			
			
# gotta have a main
if __name__ == "__main__":
	run()

EOF
	
	chmod 755 pyscript.py
	./pyscript.py
	rm ./pyscript.py		
}

function generateRunningApps ()
{
	waitSeconds=1
	while [ $waitSeconds -ge 1 ]
	do
		runningAppsList=()
		runningAppsListProcessName=()
		runningAppsListBundleID=()
		x=0
		while read appname; do
			if [[ $(ps axc | grep "$appname") != "" ]]; then
				runningAppsList+=("• ${cachedNameList[$x]}")
				runningAppsListProcessName+=("${cachedProcessList[$x]}")
				runningAppsListBundleID+=("${cachedBundleID[$x]}")
			fi
			let x=$((x+1))
		done < <(printf '%s\n' "${cachedProcessList[@]}")
		
		if [[ "${runningAppsList[@]}" == "" ]]; then
			waitSeconds=0
		fi
		sleep 1
		((waitSeconds--))
	done
	echo "running apps: ${runningAppsList[@]}"
}


function firstPrompt ()
{
	#afplay --volume 4 /System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/payment_success.aif
	##cleanup the app list for dialog
	printf -v displayAppList "%s, " "${cachedNameList[@]}"
	displayAppList=${displayAppList%?} #remove extra characters
	displayAppList=${displayAppList%?} #remove extra characters
	
	
	#define initial alert text
	descrip="Updates are available. This update takes up to 20 minutes to complete. Please save any changes to your work before clicking Update.

Updating: 
$displayAppList"

	logEntry "Software Prompt firstPrompt - updates available shown"
	RESULT=$("$JamfHelper" -startlaunchd -windowType utility -title "Splatch Update Wizard" -heading "" -description "$descrip" -button1 "Update Now" -button2 "Later" -defaultButton 1 -lockHUD -icon "$icon_folder" -iconSize "$icon_size")
	

	if [ $RESULT == 0 ]; then		
		logEntry "Software Prompt firstPrompt - user selected install now"
		attemptInstall
		exit 0
		
	elif [ $RESULT == 2 ]; then
		logEntry "Software Prompt firstPrompt - user selected later"
		schedulePrompt
		exit 0
	fi
	
}

function deferPrompt ()
{	
	printf -v displayAppList "%s, " "${cachedNameList[@]}"
	displayAppList=${displayAppList%?} #remove extra characters
	displayAppList=${displayAppList%?} #remove extra characters
	descrip="Updates are scheduled for installation. This update takes up to 20 minutes to complete. Please save any changes to your work before clicking Update.
	
$displayAppList"
	logEntry "Software Prompt deferPrompt - shown"
	RESULT=$("$JamfHelper" -startlaunchd -countdown -timeout 60 -windowType utility -title "Splatch Update Wizard" -heading "" -description "$descrip" -button1 "Update Now" -button2 "Later" -defaultButton 1 -lockHUD -icon "$icon_folder" -iconSize "$icon_size")

	if [ $RESULT == 0 ]; then
		echo "install updates, result was 0"
		logEntry "Software Prompt deferPrompt - user selected install now"
		attemptInstall
		exit 0
		
	elif [ $RESULT == 2 ]; then
		echo "user chose later"
		logEntry "Software Prompt deferPrompt - user selected later"
		schedulePrompt
		exit 0
	fi
	
}


function forcedPrompt ()
{
	#quit apps using python script
	#show list of running apps that need to be closed with coundown.
	
	logEntry "Software Prompt attemptInstall - started"
	generateRunningApps 	
	if [[ "${runningAppsList[@]}" != "" ]]; then
		echo "Apps running"
		###DO NOT ADJUST THE MARGIN IN THE TEXT BELOW
		descrip="Mandatory software updates will begin.

The following applications are running and you may close them before installation starts.

$(printf '%s\n' "${runningAppsList[@]}")
		
Installation is not optional.                                               "
		logEntry "Software Prompt attemptInstall - apps running"
		RESULT=$("$JamfHelper" -startlaunchd -countdown -timeout 60 -countdownPrompt "Time remaining " -windowType utility -title "Splatch Update Wizard" -heading "" -description "$descrip" -button1 "Continue" -defaultButton 1 -lockHUD -icon "$icon_folder" -iconSize "$icon_size")

		if [ $RESULT == 0 ]; then		
			echo "force install started"
			logEntry "Software Prompt attemptInstall - user selected Update Now"
			quitApps
			startJAMFInstall
			exit 0
			
		fi
	
	else
		#no apps running. display countdown when update will start
		descrip="Mandatory software updates will begin.

		
Installation is not optional.                                               "
		
		## Displaying Notification Window (JAMFHelper)
		
		logEntry "Software Prompt attemptInstall - apps running"
		RESULT=$("$JamfHelper" -startlaunchd -countdown -timeout 60 -countdownPrompt "Time remaining " -windowType utility -title "Splatch Update Wizard" -heading "" -description "$descrip" -button1 "Continue" -defaultButton 1 -lockHUD -icon "$icon_folder" -iconSize "$icon_size")

		if [ $RESULT == 0 ]; then		
			echo "force install started"
			logEntry "Software Prompt attemptInstall - user selected Update Now"
			startJAMFInstall
			exit 0
			
		fi
	fi
	
}

function schedulePrompt ()
{
	forceDateDisplay=$(/bin/date -jf "%s" "+%Y-%m-%d %H:%M:%S" "$forceDateEpoch")
	descrip2="Auto-Updates can be scheduled.  Select a time for auto-updates to run. You can defer the updates until $forceDateDisplay.

UPDATES WILL BE FORCED ON: 
$forceDateDisplay 

"
	
	logEntry "Software Prompt schedulePrompt - defer times shown"	
	RESULT=$("$JamfHelper" -startlaunchd -countdown -windowType utility -title "Splatch Update Wizard" -heading "" -description "$descrip2" -button1 "Schedule It" -button2 "Ignore" -showDelayOptions "900, 3600, 86400, 300, 0" -defaultButton 1 -lockHUD -icon "$icon_folder" -iconSize "$icon_size")
	
	returnlen=$(echo $RESULT | wc -c | sed -e 's/^ *//' -e 's/ .*//')
	returnln=$(($returnlen-1))
	firstnum=$(echo $RESULT | cut -c 1)
	lastnum=$(echo $RESULT | cut -c $returnln)
	timedelay=$(echo $RESULT | cut -c 1-$(($returnlen-2)))
			
	if [ $RESULT == 1 ]; then
		logEntry "Software Prompt schedulePrompt - start now selected"
		attemptInstall
		exit 0
		
	elif [ $lastnum == 1 ]; then
		logEntry "Software Prompt schedulePrompt - delay of $timedelay selected"
		deferAgentCreation
		exit 0
		
	elif [ $lastnum == 2 ]; then
		logEntry "Software Prompt schedulePrompt - ignore selected"    
		exit 0
	fi
	exit 0
	
	
}

function attemptInstall ()
{
	logEntry "Software Prompt attemptInstall - started"
	#show list of running apps that need to be closed
	generateRunningApps 	
	if [[ "${runningAppsList[@]}" != "" && $attemptInstallNumber != 2 ]]; then
		echo "Apps running"
		attemptInstallNumber=2
		###DO NOT ADJUST THE MARGIN IN THE TEXT BELOW
		descrip="The following applications are running and must be closed before continuing with this installation.
$(printf '%s\n' "${runningAppsList[@]}")
		
Close the above applications and select Continue when ready.                                               "

		logEntry "Software Prompt attemptInstall - apps running"
		RESULT=$("$JamfHelper" -startlaunchd -windowType utility -title "Splatch Update Wizard" -heading "" -description "$descrip" -button1 "Continue" -button2 "Later"  -defaultButton 1 -lockHUD -icon "$icon_folder" -iconSize "$icon_size")
		
		if [ $RESULT == 0 ]; then		
			echo "tried again"
			logEntry "Software Prompt attemptInstall - user selected Update Now"
			attemptInstall
			exit 0
			
		elif [ $RESULT == 2 ]; then
			echo "User chose Later";
			logEntry "Software Prompt attemptInstall - user selected Later"
			schedulePrompt
			exit 0
		fi

	elif [[ "${runningAppsList[@]}" != "" ]]; then
			echo "Apps running"

			###DO NOT ADJUST THE MARGIN IN THE TEXT BELOW
			descrip="The following applications are still running.
$(printf '%s\n' "${runningAppsList[@]}")
		
You can force the applications to quit if you do not have any unsaved work.                                               "

			logEntry "Software Prompt attemptInstall - apps running"
			RESULT=$("$JamfHelper" -startlaunchd -windowType utility -title "Splatch Update Wizard" -heading "" -description "$descrip" -button1 "Force Quit" -button2 "Later"  -defaultButton 1 -lockHUD -icon "$icon_folder" -iconSize "$icon_size")
		
			if [ $RESULT == 0 ]; then		
				logEntry "Software Prompt attemptInstall - user selected Force Quit"
				quitApps
				sleep 1
				startJAMFInstall
				exit 0
				
			elif [ $RESULT == 2 ]; then
				logEntry "Software Prompt attemptInstall - user selected Later"
				attemptInstallNumber=1
				schedulePrompt
				exit 0
			fi

	else
		echo "No applications running to be shut down. Continuing..."
		logEntry "Software Prompt attemptInstall - no apps running."
		startJAMFInstall
	fi
	
}


function quitApps ()
{	
	x=0
	for runningBundleID in "${runningAppsListBundleID[@]}"
	do
		pythonQuit $runningBundleID		
		let x=$((x+1))
	done
}


function writeLaunchDaemon ()
{
	
	cat << EOF > "/Library/LaunchDaemons/com.splatch.updateCheck.plist"

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.splatch.updateCheck.plist</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Library/Application Support/Splatch/updateCheck.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>300</integer>
</dict>
</plist>

EOF
	chmod 644 "/Library/LaunchDaemons/com.splatch.updateCheck.plist"
}

function writeCheckScript ()
{
	#	cat << EOF > "/Library/Application Support/Splatch/com.splatch.updateCheck.plist"
	#single quotes aroune EOF prevents variable from expanding
	cat << 'EOF' > "/Library/Application Support/Splatch/updateCheck.sh"

#!/bin/bash
SettingPLIST="/Library/Application Support/Splatch/com.splatch.softwareUpdateSettings.plist"

date >> /var/tmp/runLocal.txt

enforceDate=$(/usr/bin/defaults read "$SettingPLIST" UpdatesForcedDate 2>"/dev/null")
deferDate=$(/usr/bin/defaults read "$SettingPLIST" UpdatesDeferredUntil 2>"/dev/null")
policyName=$(/usr/bin/defaults read "$SettingPLIST" ActivePolicyName 2>"/dev/null")
modifiedDate=$(/usr/bin/defaults read "$SettingPLIST" ModifiedDate 2>"/dev/null")

echo "Deferral deadline: $(/bin/date -jf "%s" "+%Y-%m-%d %H:%M:%S" "$deferDate")"
echo $deferDate
echo "Enforce deadline: $(/bin/date -jf "%s" "+%Y-%m-%d %H:%M:%S" "$enforceDate")"
echo $enforceDate
echo "Current Date $(/bin/date +%s)"


if [[ $enforceDate -le $(( $(/bin/date +%s))) || $deferDate -le $(( $(/bin/date +%s))) ]]; then
	
	echo "time up"
	/usr/local/bin/jamf policy -trigger $policyName
else
	echo "time is not up"
	
fi
EOF
	chmod 755 "/Library/Application Support/Splatch/updateCheck.sh"
}

function deferAgentCreation ()
{

	#save setting to local plist and create launchdaemon, script, and load daemon
	#PATH="/usr/sbin:/usr/bin:/usr/local/bin:$PATH"
	
	deferredUntil=$(( $(/bin/date +%s) + $timedelay ))
	/usr/bin/defaults write "$SettingPLIST" UpdatesDeferredUntil -int "$deferredUntil"
	#echo "Deferral deadline: $(/bin/date -jf "%s" "+%Y-%m-%d %H:%M:%S" "$deferredUntil")"
	/usr/bin/defaults write "$SettingPLIST" UpdatesForcedDate -int "$forceDateEpoch"
	/usr/bin/defaults write "$SettingPLIST" ActivePolicyName -string "$policy_name_for_record"
	writeLaunchDaemon
	writeCheckScript
	launchctl load -w "/Library/LaunchDaemons/com.splatch.updateCheck.plist"
	exit 0
}

function startJAMFInstallOLD ()
{
	echo "jamf policy trigger would be running now"
	#$jamf policy -trigger installnotify
	
	
	descrip="The installation will now begin.

		
Thank you for your cooperation.  The Management.                                               "
	
	descrip2="The installation has now started.

		
Please do not user your computer during this process.                                               "
	
	## Displaying Notification Window (JAMFHelper)
	
#	RESULT=$("$JamfHelper" -windowType "hud" -windowPosition "ur" -title "Splatch Update Wizard" -heading "" -description "$descrip" -lockHUD -icon "$icon_folder" -iconSize "$icon_size")

	RESULT=$("$JamfHelper" -windowType utility -windowPosition "ur" -title "Splatch Update Wizard" -heading "" -description "$descrip" -lockHUD -icon "$icon_folder" -iconSize "$icon_size") &
	#"$JamfHelper" -windowType hud -windowPosition "ur" -title "Splatch Update Wizard" -heading "" -description "$descrip" -lockHUD -icon "$icon_folder" -iconSize "$icon_size" &
	
	sleep 2
	# /usr/bin/killall jamfHelper 2>"/dev/null"
	RESULT=$("$JamfHelper" -windowType utility -windowPosition "ur" -title "Splatch Update Wizard" -heading "" -description "$descrip2" -lockHUD -icon "$icon_folder" -iconSize "$icon_size")
	
	
#	"$JAMFHELPER" -windowType "hud" -windowPosition "ur" -icon "$LOGO" -title "$MSG_UPDATING_HEADING" -description "$MSG_UPDATING" -lockHUD &
	
	#record that the JAMF patch policy ran
	/usr/bin/defaults write "$SettingPLIST" CompletedPolicyName -string "$policy_name_for_record"}

	
}

function startJAMFInstall ()
{
	rm /var/tmp/com.depnotify.provisioning.done
	DNLOG=/var/tmp/depnotify.log
	rm -Rf $DNLOG
	rm /var/tmp/com.depnotify.provisioning.done
	#/usr/bin/caffeinate -d -i -m -u &
	caffeinatepid=$!
	# Setup DEPNotify
	echo "Command: MainTitle: Software Update Initializing" >> $DNLOG
	echo "Status: Starting up..." >> $DNLOG
	echo "Command: Image: /Library/Application Support/Splatch/DR.png" >> $DNLOG
	echo "Command: WindowStyle: NotMovable" >> $DNLOG
	echo "Command: MainText: The following components are now being updated: $displayAppList.\n Please do not use your computer." >> $DNLOG
	sleep 1
	sudo -u "$CURRENTUSER" /Library/Application\ Support/Splatch/DEPNotify.app/Contents/MacOS/DEPNotify -jamf -fullScreen &
	#sudo -u "$CURRENTUSER" /Library/Application\ Support/Splatch/DEPNotify.app/Contents/MacOS/DEPNotify -jamf &	
	echo "start sleep 10 $(date)"
	sleep 10	
	echo "sleep end 10 $(date)"
	echo "Command: MainTitle: Software Updates Installing..." >> $DNLOG
	echo "Command: WindowTitle: Splatch Application Suite Install" >> $DNLOG
	echo "Command: MainTextImage: /Library/Application Support/Splatch/globe.gif" >> $DNLOG
	#echo "Command: Image: /Library/Application Support/Splatch/DR.png" >> $DNLOG	

	
	# Install Step
	echo "Status: Installing..." >> $DNLOG
	sleep 2
	##put the install cached policy here
	
	/usr/local/bin/jamf policy -trigger installCached
	/usr/bin/defaults write "$SettingPLIST" CompletedPolicyName -string "$policy_name_for_record"}
	
	echo "Command: ContinueButton: Close" >> $DNLOG
	echo "Command: MainTitle: Software Update Complete" >> $DNLOG
	#echo "Command: MainText: Your device setup has been completed. You may now continue to use your Mac." >> $DNLOG
	echo "Command: MainText: The following components were updated: $displayAppList." >> $DNLOG
	
	echo "Status: Update Complete" >> $DNLOG
	

	DNPLIST=/var/tmp/com.depnotify.provisioning.done
	# hold here until the user enters something
	while : ; do
		[[ -f $DNPLIST ]] && break
		sleep 1
	done
	

	echo "Command: Quit: Installation complete!" >> $DNLOG
	
	rm -Rf $DNLOG
	
	
	/usr/bin/defaults write "$SettingPLIST" CompletedPolicyName -string "$policy_name_for_record"
    cleanUp


}

function cacheSoftware ()

{
	policyListToRun=()
#	echo "cachingSoftware"
	x=0
	for i in "${update_trigger[@]}"; do
		if [ "${update_trigger[$x]}" != "1" ]; then
			policyListToRun+=("${update_trigger[$x]}")
			#echo "item is ${i}"
		fi
		let x=$((x+1))
	done
	#echo $policyListToRun
	
	
	for triggername in "${policyListToRun[@]}"; do
		/usr/local/bin/jamf policy -trigger $triggername
	done

}



function cleanUp ()

{
	echo "cleaning up files"
    rm /Library/LaunchDaemons/com.splatch.updateCheck.plist
	launchctl remove com.splatch.updateCheck.plist
	launchctl unload com.splatch.updateCheck.plist
}

function launchPrompt ()

{
	####FOR TESTING
	#/usr/bin/defaults write "$SettingPLIST" ActivePolicyName -string "$policy_name_for_record"	
	#/usr/bin/defaults write "$SettingPLIST" CompletedPolicyName -string "$policy_name_for_record"	
	
	#make forced date in the past
	#comment first line of launchPromt too
	#/usr/bin/defaults write "$SettingPLIST" UpdatesForcedDate -int 1608439758
	
	#make deferral date in the past
	#/usr/bin/defaults write "$SettingPLIST" UpdatesDeferredUntil -int 1608353358
	
	#make deferral date to 2024
	#/usr/bin/defaults write "$SettingPLIST" UpdatesDeferredUntil -int 1734929358

	
	#write forced date to settings so it can be enforced on first run 
	/usr/bin/defaults write "$SettingPLIST" UpdatesForcedDate -string "$forceDateEpoch"

	#import the local settings to compare
	completePolicy=$(/usr/bin/defaults read "$SettingPLIST" CompletedPolicyName 2>"/dev/null")	
	activePolicy=$(/usr/bin/defaults read "$SettingPLIST" ActivePolicyName 2>"/dev/null")		
	enforceDate=$(/usr/bin/defaults read "$SettingPLIST" UpdatesForcedDate 2>"/dev/null")
	deferDate=$(/usr/bin/defaults read "$SettingPLIST" UpdatesDeferredUntil 2>"/dev/null")
	
	#check to see if this jamf policy completed already
	if [ "$completePolicy" == "$policy_name_for_record" ]; then		
		echo "ALREADY RUN"
		cleanUp 
		exit 0

	#check to see if this policy have ever been recorded				
	elif [ "$activePolicy" != "$policy_name_for_record" ]; then		
		echo "NEVER RUN"
		activePolicy=$(/usr/bin/defaults read "$SettingPLIST" ActivePolicyName 2>"/dev/null")		
		cacheSoftware
		createCachedList
		createAppRays
		firstPrompt 
		exit 0
	fi
	
	#check to see if enforcement date has passed			
	if [[  ( -n $enforceDate ) && $enforceDate -le $(( $(/bin/date +%s))) ]]; then
		echo "FORCED"
		createCachedList
		createAppRays
		forcedPrompt
		exit 0

	#check if user deferral has expired
	elif [[ ( -n $deferDate ) && $deferDate -le $(( $(/bin/date +%s))) ]]; then
		echo "DEFER IS UP"
		createCachedList
		createAppRays
		deferPrompt 
		exit 0

	#confirm there is a deferral date set in the future
	elif [[ ( -n $deferDate ) && $deferDate -ge $(( $(/bin/date +%s))) ]]; then
		echo "DEFER IS SET.  DO OT RUN"
		exit 0

	#not sure how we got here
	else
	echo "RUN ANYWAY"
		createCachedList
		createAppRays
		deferPrompt 
	
	fi
	
}


####
#### Main Execution
####
launchPrompt


