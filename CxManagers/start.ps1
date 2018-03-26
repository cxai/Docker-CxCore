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
# start the service
# follow the correct startup sequence, although if job manager is started first it will just kick off the others
Write-Host "Starting CxSAST Scans Manager ..."
Start-Service "CxScansManager" -WarningAction SilentlyContinue
Write-Host "Starting CxSAST System Manager ..."
Start-Service "CxSystemManager" -WarningAction SilentlyContinue
Write-Host "Starting CxSAST Jobs Manager ..."
Start-Service "CxJobsManager" -WarningAction SilentlyContinue

Add-Type -AssemblyName System.ServiceProcess -ErrorAction SilentlyContinue

$service1 = New-Object System.ServiceProcess.ServiceController("CxJobsManager")
try { $service1.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[System.TimeSpan]::FromSeconds(10)) }
catch { throw "Timed out waiting for the CxJobsManager service to start" }

$service2 = New-Object System.ServiceProcess.ServiceController("CxScansManager")
try { $service2.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[System.TimeSpan]::FromSeconds(10)) }
catch { throw "Timed out waiting for the CxScansManager service to start" }

$service3 = New-Object System.ServiceProcess.ServiceController("CxSystemManager")
try { $service3.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[System.TimeSpan]::FromSeconds(10)) }
catch { throw "Timed out waiting for the CxSystemManager service to start" }

Write-Host "Started." -ForegroundColor green

# Check if there is a localhost engine registered and unregister it, since none is installed on this container
# https://checkmarx.atlassian.net/wiki/spaces/KC/pages/135594133/Engine+Auto+Scaling+v8.5.0+and+up
<#Write-Host "Removing default localhost engine record..."
$admin="{username:'$sast_admin',password:'$sast_adminpwd'}"
$JSONResponse=Invoke-RestMethod -uri http://$sast_server/cxrestapi/auth/login -method post -body $admin -contenttype 'application/json' -sessionvariable sess
if(!$JSONResponse){ throw "Could not authenticate" }

$headers=@{"CXCSRFToken"=$sess.Cookies.GetCookies("http://$sast_server/cxrestapi/auth/login")["CXCSRFToken"].Value}
try { 
   Invoke-RestMethod -uri http://$sast_server/cxrestapi/sast/engineservers/1 -method delete -contenttype 'application/json' -headers $headers -WebSession $sess
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    throw "Could not delete default enginer config"
} 
#>

# tailing log and checking the process state. Assuming the log is not here yet.
$logfile1="C:\CxSAST\Logs\JobsManager\CxJobsManager.Log"
$logfile2="C:\CxSAST\Logs\SystemManager\CxSystemManager.Log"
$logfile3="C:\CxSAST\Logs\ScansManager\CxScanManager.Log"
$start1=0
$start2=0
$start3=0
do {
	Start-Sleep -s 1
	$service1.Refresh()
	if ((Test-Path $logfile1) -and ((gc $logfile1) -ne $null)) {
		$log1=gc $logfile1
		$end1=$log1.length
		(gc $logfile1)[$start1..$end1]
		$start1=$end1
	}
	if ((Test-Path $logfile2) -and ((gc $logfile2) -ne $null)) {
		$log2=gc $logfile2
		$end2=$log2.length
		(gc $logfile2)[$start2..$end2]
		$start2=$end2
	}
	if ((Test-Path $logfile3) -and ((gc $logfile3) -ne $null)) {
		$log3=gc $logfile3
		$end3=$log3.length
		(gc $logfile3)[$start3..$end3]
		$start3=$end3
	}

} while ($service1.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running `
	-and $service2.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running `
	-and $service3.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)

Write-Host "Stopped."

# return status of the first stopped service
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
[Interop.Advapi32]::QueryServiceStatus($service1.ServiceHandle, [ref] $status) | Out-Null
$exitstring = [System.String]::Format("Exit Status as {0}", $status.win32ExitCode)
if ($status.win32ExitCode -ne 0) {
	Write-Error $exitstring
} else {
	Write-Host $exitstring
}

exit $status.win32ExitCode
