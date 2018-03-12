param(
[Parameter(Mandatory=$false)]
[string]$sast_admin,

[Parameter(Mandatory=$false)]
[string]$sast_adminpwd
)

if ($null -eq $sast_admin -or $null -eq $sast_adminpwd -or $$sast_admin -eq '_' -or $$sast_adminpwd -eq '_') {
  Write-Verbose "Please, provide SAST admin user name and password so this engine can be registered with the manager"
  exit 1
}

# Check for license and it's correctness, print HID if not, start CxSAST if it's there.
if (!(Test-Path "c:\CxSAST\Licenses\license.cxl")) {
  # first generate the HID, we'll need it later
  #c:\CxSAST\HidGenerator.exe | out-null - does not work, hungs forever :(
  Start-Process "c:\CxSAST\HidGenerator.exe"
  # kind of a lame busy wait till hid generator is done
  while (!(Test-Path "c:\CxSAST\HardwareId.txt")) {
  	Start-Sleep -Seconds 1
  }
  # dont need anymore, kill it.
  Get-Process | Where-Object { $_.Name -eq "HidGenerator" } | Select-Object -First 1 | Stop-Process
  # now onto the license checks 
  if (!(Test-Path "c:\temp\license.cxl")) {  
  	Write-Host "Can not start CxSAST. Please provide a license.cxl file in c:\temp\ for the following HID:" -ForegroundColor red
	cat c:\CxSAST\HardwareId.txt
	exit 1
  } else {
	# check if the provided license is correct by searching for the trimmed HID inside cxl. cxl needs to be converted from utf32 to utf8
	$hid=(Select-String -path .\HardwareId.txt -Pattern "#([^_]*)").Matches.Groups[1].Value
	if (!((Get-content -Path "c:\temp\license.cxl") -match $hid)){    
	 	Write-Host "Can not start CxSAST. license.cxl does not match the HID for this container:" -ForegroundColor red
		cat c:\CxSAST\HardwareId.txt
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
Write-Host "Joining CxSAST Engine..."

#$person = @{username='admin@cx';password='admin'}
#$admin=(convertto-json $person)  
$admin="{username:'$sast_admin',password:'$sast_adminpwd'}"
$JSONResponse=Invoke-RestMethod -uri http://manager/cxrestapi/auth/login -method post -body $admin -contenttype 'application/json' -sessionvariable sess
if(!$JSONResponse){ throw "Could not authenticate" }

$headers=@{"CXCSRFToken"=$sess.Cookies.GetCookies("http://manager/cxrestapi/auth/login")["CXCSRFToken"].Value}
$JSONResponse=invoke-restmethod -uri http://manager/cxrestapi/sast/engineservers -method get -contenttype 'application/json' -headers $headers -WebSession $sess
if(!$JSONResponse){ throw "Error listing servers" }


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
