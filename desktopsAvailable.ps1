﻿# This script will alarm if the percent of available desktops exceeds a defined Warning or Critical threshold.
# The percentage available is calculated using the number of remote sessions and desktops provisioned within the pool.
# 
Param(
	# View Desktop Pool ID to monitor
	[Parameter(Mandatory=$true)]
	[string]$PoolId,

	# Percent utilized desktops to trigger Warning
	# Not required, default is 1
	[int]$WarningLevel = 75,

	# Percent utilized desktops to trigger Critical
	# Not required, default is 0
	[int]$CriticalLevel = 80,

	$DebugPreference = "SilentlyContinue"
)

Write-Debug "Pool: $PoolId"
Write-Debug "Warning Level: $WarningLevel%"
Write-Debug "Critical Level: $CriticalLevel%"

# Load the required VMware View Powershell cmdlets
add-PSSnapin -Name vmware.view.broker -ErrorAction SilentlyContinue

# Nagios return values
$ReturnStateOK = 0
$ReturnStateWarning = 1
$ReturnStateCritical = 2
$ReturnStateUnknown = 3

# number of remote sessions for the pool
$SessionCount = 0

# Percent utilized desktops in the pool
$PercentUtilized = 0

# nagios formated service performance data
# https://www.monitoring-plugins.org/doc/guidelines.html
$NagiosData = "percent_utilized=$PercentUtilized;;;;"

# input validation
# Number of desktops to trigger Warning must always be less than Critical.
if ( $WarningLevel -ge $CriticalLevel) {
	Write-Host "Unknown: Bad input. WarningLevel $WarningLevel must not be less than CriticalLevel $CriticalLevel. | $NagiosData"
	exit $ReturnStateUnknown
}

# Get the pool ID
$Pool = Get-Pool -Pool_id $PoolId -ErrorAction SilentlyContinue

# if no pool ID is returned then exit
if (!($Pool)) {
	Write-Host "Unknown: The pool $PoolId is unknown. | $NagiosData"
	exit $ReturnStateUnknown
}

# get the sessions for the pool
# Get-RemoteSession will return null if there are no sessions
$SessionCount = (Get-RemoteSession -Pool_id $Pool.pool_id -ErrorAction SilentlyContinue).count

# if there are no sessions for the Pool then set to SessionCount 0
if ($SessionCount) {
	Write-Debug "Number of sessions for the pool $PoolId is $SessionCount"
} else {
	$SessionCount = 0
	Write-Debug "Sessions was null. Setting SessionCount to 0."
}

# provisioned desktops in a pool
$ProvisionedDesktops = (Get-DesktopVM -Pool_id $PoolId -ErrorAction SilentlyContinue).count

# if there are no desktops provisioned for the Pool then set ProvisionedDesktops to 0
if ($ProvisionedDesktops) {
	Write-Debug "Number of provisioned desktops for the pool $PoolId is $ProvisionedDesktops"
} else {
	$ProvisionedDesktops = 0
	Write-Debug "Get-DesktopVM for pool $PoolId was null. Setting ProvisionedDesktops to 0."
}

# percent of available desktops in the pool
$PercentUtilized = [decimal]::Round(($SessionCount/$ProvisionedDesktops) * 100)
Write-Debug "Percent utilized $PercentUtilized% = (Session Count $SessionCount / Provisioned Desktops $ProvisionedDesktops ) * 100"

# if the percentage of available desktops is negative or greater than 100 then something is wrong
if ( ($PercentUtilized -lt 0) -or ($PercentUtilized -gt 100)) {
	Write-Host "Unknown: Percent utilized is out of range $PercentUtilized% in $PoolId | $NagiosData"
	exit $ReturnStateUnknown
}

# data formated for Nagios
$NagiosData = "percent_utilized=$PercentUtilized;;;;"

# Nagios return states
if ($PercentUtilized -ge $CriticalLevel) {
	Write-Host "CRITICAL: $PercentUtilized% desktops available in $PoolId | $NagiosData"
	exit $ReturnStateCritical
	}
elseif ($PercentUtilized -ge $WarningLevel) {
	Write-Host "WARNING: $PercentUtilized% desktops available in $PoolId | $NagiosData"
	exit $ReturnStateWarning
	}
elseif ($PercentUtilized -lt $WarningLevel) {
	Write-Host "OK: $PercentUtilized% desktops available in $PoolId | $NagiosData"
	exit $ReturnStateOK
	}
else {
	Write-Host "Unknown: $PercentUtilized% desktops in $PoolId | $NagiosData"
	exit $ReturnStateUnknown
}