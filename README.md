# SCOM

## Description
This integration uses the powershell command line function within Microsoft System Center Operations Manager to send alerts to PagerDuty.

## Setup
In the Operations Console, head to Administration and create a new Command Notification Channel. When prompted for the following Settings information in the Command Notification Channel, provide the following values:

	Full Path of the Command File:			C:\windows\system32\windowspowershell\v1.0\powershell.exe
	Command Line Parameters:			-F "C:\scripts\pagerduty\pagerduty.ps1" -AlertID "$Data[Default='NotPresent']/Context/DataItem/AlertId$"
	Startup Folder for the Command Line:		C:\windows\system32\windowspowershell\v1.0\

#### Note
The Command Line Parameters assume that you have downloaded the powershell script pagerduty.ps1 and have it available in the C:\scripts\pagerduty\ directory.

To obtain an "Integration Key" to be passed into the Command Line Parameter, go into your PagerDuty Account > Configuration > Services and select the service you want to send alerts to. Create the integration "Microsoft SCOM" and you'll be provided an "Integration Key".

This integration uses the Operations Manager Module to obtain Alert information. Please identify the proper the path to the Operations Manager in your SCOM environment and provide that path in Line 8 of the Powershell script.