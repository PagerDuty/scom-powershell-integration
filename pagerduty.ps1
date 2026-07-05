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

# Truncate a string to a max length, appending "..." if cut
function Limit-String {
    param([String]$s, [int]$max = 4096)
    if ($s.Length -gt $max) { $s.Substring(0, $max - 3) + "..." } else { $s }
}

# Construct PagerDuty Event Summary within 1024 characters API limit prioritizing Hostname, Alert Name, and Description

[String]$RawSummary = ($Hostname + " - " + $Alert.Name + " - " + $Alert.Description).Trim() 
[String]$AlertSummary = if ($RawSummary.Length -gt1024) { $RawSummary.Substring(0, 1021) + "..." } else { $RawSummary }


# Look Up Custom Details with Fallbacks and Truncate to 4096 characters to avoid exceeding PagerDuty total payload API limit

[String]$Priority	= Limit-String $(if ($Alert.Priority){$Alert.Priority} else {"Not Available"})
[String]$CustomField1 	= Limit-String $(if ($Alert.CustomField1){$Alert.CustomField1} else {"Not Available"})
[String]$CustomField2	= Limit-String $(if ($Alert.CustomField2){$Alert.CustomField2} else {"Not Available"})
[String]$CustomField3 	= Limit-String $(if ($Alert.CustomField3){$Alert.CustomField3} else {"Not Available"})
[String]$CustomField4	= Limit-String $(if ($Alert.CustomField4){$Alert.CustomField4} else {"Not Available"})
[String]$CustomField5	= Limit-String $(if ($Alert.CustomField5){$Alert.CustomField5} else {"Not Available"})
[String]$CustomField6	= Limit-String $(if ($Alert.CustomField6){$Alert.CustomField6} else {"Not Available"})
[String]$CustomField7	= Limit-String $(if ($Alert.CustomField7){$Alert.CustomField7} else {"Not Available"})
[String]$CustomField8	= Limit-String $(if ($Alert.CustomField8){$Alert.CustomField8} else {"Not Available"})
[String]$CustomField9	= Limit-String $(if ($Alert.CustomField9){$Alert.CustomField9} else {"Not Available"})
[String]$CustomField10	= Limit-String $(if ($Alert.CustomField10){$Alert.CustomField10} else {"Not Available"})

# Construct PagerDuty Events Payload

$AlertPayload = @{
	routing_key 			= $RoutingKey
	event_action 			= $Event
	dedup_key 			= Limit-String ($AlertID.Trim('{}')) 255
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

$json = ConvertTo-Json -InputObject $AlertPayload -Depth 5
if ([System.Text.Encoding]::UTF8.GetByteCount($json) -gt 524288) {
    $AlertPayload.payload.custom_details = @{ truncated = "Payload exceeded 512KB limit; custom details omitted." }
    $json = ConvertTo-Json -InputObject $AlertPayload -Depth 5
}

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
