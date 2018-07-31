#!/bin/bash
# Russ Thompson 2018 russ@linux.com
# Sends alerts from AWS Guard Duty to Slack or Mattermost (or other compatible chat)
# Requires: aws command line tool and jq

### Required settings

# The slack or mattermost web hook URL
WEB_HOOK_URL="https://something-slack.com/hooks/jtbos8akj7ndjb83wutnrradih"

# When sending an alert, a single tag (such as instance name) can be included, place the tag name here.
# If the tag doesn't exist on an instance, it will be replaced with 'null'
INSTANCE_TAG="MyTag"

### Optional settings (defaults are acceptable)

# Storage for events already alerted on (stores eventID to avoid duplicate alerts)
EVENT_STORAGE_FILE="/tmp/guardduty-events"

# When the event severity is greater than MAJOR_ALERT_SEVERITY, we ping the entire channel (more noise)
# Generally events above a '5' severity are notable
MAJOR_ALERT_SEVERITY="5"

# How many seconds in between each check for new guard duty events
CHECK_INTERVAL="60"

# Define IGNORE_INSTANCE to avoid sending alerts for this instance (e.g vulnerability scanners)
# You can set this to an instance ID, security group, etc.  Leave default setting to disable
IGNORE_INSTANCE="i-123456789abc"

### No need to edit anything below this line.

readonly BASE_NAME=$(basename -- "$0")
readonly DIRECTOR_ID="$(aws guardduty list-detectors | jq -r .DetectorIds[])"

touch $EVENT_STORAGE_FILE

# FUNCTION (send_mm_alert):  Send an alert to Slack, Mattermost etc using the data we obtained earlier
function send_mm_alert(){
  if [[ ! "$(echo $EVENT_DATA)" == *"$IGNORE_INSTANCE"* ]] ; then
    if [ $GD_SEVERITY -gt $MAJOR_ALERT_SEVERITY ] ; then
      curl -s -i -X POST -H 'Content-Type: application/json' -d \
      '{"username": "guardduty-bot", "text": "** <!channel> '"$GD_MESSAGE"' ** [`'"$GD_INSTANCE_TAG"'`]\n * Event: UID='$GD_EVENT_ID' | Time='$GD_EVENT_TIME' | Count='$GD_COUNT' | Severity='$GD_SEVERITY' | Source=GuardDuty"}' \
      $WEB_HOOK_URL
      logger -t INFO "$BASE_NAME [alert-notable]:  $GD_MESSAGE UID=$GD_EVENT_ID"
    else
      curl -s -i -X POST -H 'Content-Type: application/json' -d \
      '{"username": "guardduty-bot", "text": "** Alert: '"$GD_MESSAGE"' ** [`'"$GD_INSTANCE_TAG"'`]\n * Event: UID='$GD_EVENT_ID' | Time='$GD_EVENT_TIME' | Count='$GD_COUNT' | Severity='$GD_SEVERITY' | Source=GuardDuty"}' \
      $WEB_HOOK_URL
      logger -t INFO "$BASE_NAME [alert-basic]:  $GD_MESSAGE UID=$GD_EVENT_ID"
    fi      
  else
    # Log as warning when an event comes in that matches our IGNORE_INSTANCE
    logger -t WARN  "$BASE_NAME [alert-ignored]:  $GD_MESSAGE UID=$GD_EVENT_ID"
  fi
  EVENT_DATA=""
  # Remove existing events with the same UID and different count
  sed -i "/$gd_events/d" $EVENT_STORAGE_FILE
  echo $GD_EVENT_AND_COUNT >> $EVENT_STORAGE_FILE
}

# FUNCTION (parse_event_data):  Parse the event JSON data with the jq utility, place useful data into variables.
function parse_event_data(){
  GD_MESSAGE="$(echo $EVENT_DATA | jq -r .Findings[].Title)"
  GD_COUNT="$(echo $EVENT_DATA | jq -r .Findings[].Service.Count?)"
  GD_SEVERITY="$(echo $EVENT_DATA | jq -r .Findings[].Severity)"
  # eventLastSeen
  GD_EVENT_TIME="$(echo $EVENT_DATA | jq -r .Findings[].Service.EventFirstSeen?)"
  GD_EVENT_ID="$(echo $EVENT_DATA | jq -r .Findings[].Id)"
  GD_INSTANCE_TAG="$(echo $EVENT_DATA | jq -r '.Findings[].Resource[].Tags? | map(select(.Key == '\"$INSTANCE_TAG\"')) | .[].Value')"
  GD_EVENT_AND_COUNT="$gd_events:$GD_COUNT"
  # Instance details aren't provided on user activity, grab username field (if available)
  if [ -z "$GD_INSTANCE_TAG" ] ; then GD_INSTANCE_TAG="null" ; fi

  if ! grep -w $GD_EVENT_AND_COUNT $EVENT_STORAGE_FILE ; then 
    send_mm_alert
  fi
}

# Loop through the current findings
while true ; do
  for gd_events in `aws guardduty list-findings --detector-id $DIRECTOR_ID | jq -r .FindingIds[]` ; do
    # Check our events file to see if this is a new event or old.
      EVENT_DATA="$(aws guardduty get-findings --detector-id $DIRECTOR_ID --finding-ids $gd_events)"
      # Parse the data of any events discovered
      parse_event_data 
  done
  sleep $CHECK_INTERVAL
done
