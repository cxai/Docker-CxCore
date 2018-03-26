param(
[Parameter(Mandatory=$false)]
[string]$sast_server,

[Parameter(Mandatory=$false)]
[string]$sast_admin,

[Parameter(Mandatory=$false)]
[string]$sast_adminpwd
)

if ($null -eq $sast_server -or $null -eq $sast_admin -or $null -eq $sast_adminpwd -or $sast_server -eq '_' -or $sast_admin -eq '_' -or $sast_adminpwd -eq '_') {
  Write-Verbose "Please, provide SAST server name, admin user name and password so this engine can be registered"
  exit 1
}

# NOTE The license code below is not necessary for the engine from 8.7 onward. Leaving it here for compatibility reasons
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
# start the service
Write-Host "Starting CxSAST Engine..."

Add-Type -AssemblyName System.ServiceProcess -ErrorAction SilentlyContinue
Start-Service "CxScanEngine" -WarningAction SilentlyContinue
$service = New-Object System.ServiceProcess.ServiceController("CxScanEngine")
try { $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[System.TimeSpan]::FromSeconds(10)) }
catch { throw "Timed out waiting for the service to start" }

Write-Host "Started." -ForegroundColor green

# Add to the list of available engines
Write-Host "Registering the CxSAST Engine..."

#$person = @{username='admin@cx';password='admin'}
#$admin=(convertto-json $person)  
$admin="{username:'$sast_admin',password:'$sast_adminpwd'}"
$JSONResponse=Invoke-RestMethod -uri http://$sast_server/cxrestapi/auth/login -method post -body $admin -contenttype 'application/json' -sessionvariable sess
if(!$JSONResponse){ throw "Could not authenticate" }

$headers=@{"CXCSRFToken"=$sess.Cookies.GetCookies("http://$sast_server/cxrestapi/auth/login")["CXCSRFToken"].Value}
#$JSONResponse=invoke-restmethod -uri http://$sast_server/cxrestapi/sast/engineservers -method get -contenttype 'application/json' -headers $headers -WebSession $sess
#if(!$JSONResponse){ throw "Error listing servers" }

$engine='{"name":"'+$(hostname)+'","uri":"http://'+$(hostname)+'/CxSourceAnalyzerEngineWCF/CxEngineWebSerices.svc","minLoc":0,"maxLoc":99999999,"isBlocked":false}'
try { 
   Invoke-RestMethod -uri http://$sast_server/cxrestapi/sast/engineservers -method post -body $engine -contenttype 'application/json' -headers $headers -WebSession $sess
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    throw "Could not register"
} 

# tailing log and checking the process state. Assuming the log is not here yet.
$logfile="C:\CxSAST\Checkmarx Engine Server\Logs\Engine.log"
$start=0
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
