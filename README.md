# aws-guardduty-slack
Consumes AWS (Amazon Web Services) Guard Duty events and sends alerts to Slack, Mattermost and other compatible chats.

## Requires
AWS command line interface [found here](https://aws.amazon.com/cli/).

JQ command line JSON processor [found here](https://stedolan.github.io/jq/)

Note: Both can typically be installed using linux package managers (e.g yum and apt-get)

## Configuration
Open `aws-guardduty-notifications.sh` in a text editor, towards the top edit the setting `WEB_HOOK_URL` this is the **only required** configurable option.  Other changeable parameters exist but the defaults are acceptable, these optionals are listed below

`IGNORE_INSTANCE`: you can define an instance to white list, avoids sending alerts for this instance.

`MAJOR_ALERT_SEVERITY`: Alerts above this guard duty severity make additional chat noise by pinging the entire channel. [DEFAULT=5]

`CHECK_INTERVAL`: How often to check for new guard duty events, in seconds. [DEFAULT=60]

`EVENT_STORAGE_FILE`: The file where we store existing events that have already had alerts sent

## Executing
Once configured, you can simply execute the script as a background process or via screen.

Screen example: `screen -A -m -d -S aws-guardduty-notifications bash aws-guardduty-notifications.sh &` this will place it in a screen that has a label of `aws-guardduty-notifications`

Also included is a traditional init script that can start and stop the monitor, to use this script, place the init script in /etc/init.d and make exectuable.  Place the monitor script in /opt/aws-guardduty-notifications/aws-guardduty-notifications.sh and you're all set.

## Example alert
![alt tag](https://github.com/vigeek/aws-elb-logs-to-logstash/blob/master/kibana-dashboard/guard-duty-alerts.png)
