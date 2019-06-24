Param (
	[Parameter(Position=0,mandatory=$true)]		[String]$AlertID,
	[Parameter(Position=1,mandatory=$false)]	[String]$RoutingKey = "ENTER INTEGRATION KEY HERE",
	[Parameter(Position=2,mandatory=$false)]	[String]$Url = "https://events.pagerduty.com/v2/enqueue"
)

# Import Operations Manager to Retrieve Alert Information
Import-Module "C:\Program Files\Microsoft System Center 2016\Operations Manager\Powershell\OperationsManager\OperationsManager.psm1"

# Get Alert Information
$Alert = Get-SCOMAlert -id $AlertID

# Determine the Event Action
switch ($Alert.ResolutionState){
        0       	{$Event="trigger"}
        254		{$Event="resolve"} 
        255     	{$Event="resolve"}
        default 	{$Event="trigger"}
    }

# Determine the Severity
switch ($Alert.Severity){
	"Information"	{$Severity="info"}
	"Warning"	{$Severity="warning"}
	"Error"		{$Severity="error"}
	"Critical"	{$Severity="critical"}
	default		{$Severity="critical"}
}


# Determine Host

[String]$Hostname = if($Alert.NetbiosComputerName){$Alert.NetbiosComputerName}
elseif($Alert.MonitoringObjectPath){$Alert.MonitoringObjectFullName}
elseif($Alert.MonitoringObjectName){$Alert.MonitoringObjectName}
else {"Hostname Not Available"}


# Construct PagerDuty Event Summary

[String]$AlertSummary = ($Hostname + " - " + $Alert.Name + " - " + $Alert.Description).Trim()


# Look Up Custom Details

[String]$Priority	= if ($Alert.Priority){$Alert.Priority} else {"Not Available"}
[String]$CustomField1 	= if ($Alert.CustomField1){$Alert.CustomField1} else {"Not Available"}
[String]$CustomField2	= if ($Alert.CustomField2){$Alert.CustomField2} else {"Not Available"}
[String]$CustomField3 	= if ($Alert.CustomField3){$Alert.CustomField3} else {"Not Available"}
[String]$CustomField4	= if ($Alert.CustomField4){$Alert.CustomField4} else {"Not Available"}
[String]$CustomField5	= if ($Alert.CustomField5){$Alert.CustomField5} else {"Not Available"}
[String]$CustomField6	= if ($Alert.CustomField6){$Alert.CustomField6} else {"Not Available"}
[String]$CustomField7	= if ($Alert.CustomField7){$Alert.CustomField7} else {"Not Available"}
[String]$CustomField8	= if ($Alert.CustomField8){$Alert.CustomField8} else {"Not Available"}
[String]$CustomField9	= if ($Alert.CustomField9){$Alert.CustomField9} else {"Not Available"}
[String]$CustomField10	= if ($Alert.CustomField10){$Alert.CustomField10} else {"Not Available"}

# Construct PagerDuty Events Payload

$AlertPayload = @{
	routing_key 			= $RoutingKey
	event_action 			= $Event
	dedup_key 			= $AlertID.Trim('{}')
	payload = @{
		summary 		= $AlertSummary
		severity 		= $Severity
		source			= $Hostname
		timestamp		= $Alert.TimeRaised.ToString("o")
		custom_details		= @{
			Priority	= $Priority
			CustomField1 	= $CustomField1
			CustomField2	= $CustomField2
			CustomField3 	= $CustomField3
			CustomField4	= $CustomField4
			CustomField5	= $CustomField5
			CustomField6	= $CustomField6
			CustomField7	= $CustomField7
			CustomField8	= $CustomField8
			CustomField9	= $CustomField9
			CustomField10	= $CustomField10
		}
	}
}

# Convert Events Payload to JSON

$json = ConvertTo-Json -InputObject $AlertPayload

$logEvents = "C:\scripts\pagerduty\pagerduty_log.txt"


# Send to PagerDuty and Log Results

$LogMtx = New-Object System.Threading.Mutex($False, "LogMtx")
$LogMtx.WaitOne() | Out-Null

try {
    Invoke-RestMethod	-Method Post `
    					-ContentType "application/json" `
    					-Body $json `
    					-Uri $Url `
    					| Out-File $logEvents -Append
}

catch {
    out-file -InputObject "Exception Type: $($_.Exception.GetType().FullName) Exception Message: $($_.Exception.Message) AlertID = $AlertID Alert = $Alert ResolutionState = $Alert.ResolutionState Summary = $AlertSummary" -FilePath $logEvents -Append
}

finally {
	$LogMtx.ReleaseMutex() | Out-Null
}
