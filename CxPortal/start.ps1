# Check for license and it's correctness, print HID if not, start CxSAST if it's there.
if (!(Test-Path "c:\CxSAST\Licenses\license.cxl")) {
  $hidall=(& "c:\CxSAST\HID\HID.exe") | out-string
  if (!(Test-Path "c:\temp\license.cxl")) {  
  	Write-Host "Please provide a license.cxl file for the following HID: $hidall" -ForegroundColor red
	exit 1
  } else {
  	$hid=(Select-String -inputObject $hidall -Pattern "#([^_]*)").Matches.Groups[1].Value
  	if (!((Get-content -Path "c:\temp\license.cxl") -match $hid)){    
		Write-Host "Provided license.cxl does not match the HID for this container: $hidall" -ForegroundColor red
		exit 1
  	} else {
		Write-Host "Deploying the license..." -ForegroundColor green
		copy c:\temp\license.cxl c:\CxSAST\Licenses\license.cxl
  	}
  }
}
# check if forwarders need to be configured (first start vs restarted container)
if (! (Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/proxy" -name 'enabled').value ) {
	if (($null -eq $env:sast_manager) -or ($env:sast_manager -eq '_')) {
		Write-Host "Missing sast_manager environment variable to configure API forwarders..."  -ForegroundColor red
		exit 1
	}
	Write-Host "Configuring API forwarders to $env:sast_manager ..."
	stop-Service "W3SVC"
	stop-Service "WAS"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/proxy" -name "enabled" -value "True"
	Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules" -name "." -value @{name='ReverseProxyInboundRule1';stopProcessing='True'}
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule1']/match" -name "url" -value ".*(cxwebinterface/.*)"
	Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule1']/conditions" -name "." -value @{input='{CACHE_URL}';pattern='^(https?)://'}
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule1']/action" -name "url" -value "{C:1}://$env:sast_manager/{R:1}"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule1']/action" -name "type" -value "Rewrite"
	Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules" -name "." -value @{name='ReverseProxyInboundRule2';stopProcessing='True'}
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule2']/match" -name "url" -value ".*(cxrestapi/.*)"
	Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule2']/conditions" -name "." -value @{input='{CACHE_URL}';pattern='^(https?)://'}
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule2']/action" -name "url" -value "{C:1}://$env:sast_manager/{R:1}"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule2']/action" -name "type" -value "Rewrite"
	Add-Type -AssemblyName System.ServiceProcess -ErrorAction SilentlyContinue
	Start-Service "WAS" -WarningAction SilentlyContinue
	Start-Service "W3SVC" -WarningAction SilentlyContinue
}
# start the service
Write-Host "Starting CxSAST Portal..."

$service = New-Object System.ServiceProcess.ServiceController("W3SVC")
try { $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[System.TimeSpan]::FromSeconds(10)) }
catch { throw "Timed out waiting for the service to start" }

Write-Host "Started." -ForegroundColor green

# Write-Host "Pre-Building cache." -ForegroundColor green

# tailing log and checking the process state. Assuming the log is not here yet.
$logfile="C:\CxSAST\Logs\WebClient\Portal.log"
#$log=gc $logfile
#$start=$log.length
$start=0
#$log
do {
	Start-Sleep -s 1
	$service.Refresh()
	if ((Test-Path $logfile) -and ((gc $logfile) -ne $null)) {
		$log=gc $logfile
		$end=$log.length
		(gc $logfile)[$start..$end]
		$start=$end
	}
} while ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)


Write-Host "Stopped."
# Get service status
Add-Type -Name Advapi32 -Namespace Interop -PassThru -MemberDefinition @'
            [StructLayout(LayoutKind.Sequential)]
            public struct SERVICE_STATUS
            {
                public int serviceType;
                public int currentState;
                public int controlsAccepted;
                public int win32ExitCode;
                public int serviceSpecificExitCode;
                public int checkPoint;
                public int waitHint;
            }
            [DllImport("api-ms-win-service-winsvc-l1-1-0.dll", CharSet = CharSet.Unicode, SetLastError=true)] 
                public static extern bool QueryServiceStatus(System.Runtime.InteropServices.SafeHandle serviceHandle,out SERVICE_STATUS pStatus);
'@ | Out-Null 
$status = New-Object Interop.Advapi32+SERVICE_STATUS
[Interop.Advapi32]::QueryServiceStatus($service.ServiceHandle, [ref] $status) | Out-Null
$exitstring = [System.String]::Format("Exit Status as {1}", $status.win32ExitCode)
if ($status.win32ExitCode -ne 0) {
	Write-Error $exitstring
} else {
	Write-Host $exitstring
}

exit $status.win32ExitCode
