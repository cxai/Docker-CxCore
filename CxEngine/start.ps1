# NOTE The license code below is not necessary for the engine. It just warns and continues
if (!(Test-Path "c:\CxSAST\Licenses\license.cxl")) {
  $hidall=(& "c:\CxSAST\HID\HID.exe") | out-string
  if (!(Test-Path "c:\temp\license.cxl")) {  
  	Write-Host "Warning: There is no license file. HID: $hidall" -ForegroundColor yellow
  } else {
  	$hid=(Select-String -inputObject $hidall -Pattern "#([^_]*)").Matches.Groups[1].Value
  	if (!((Get-content -Path "c:\temp\license.cxl") -match $hid)){    
		Write-Host "Warning: The provided license.cxl does not match the HID for this container: $hidall" -ForegroundColor yellow
  	} else {
		Write-Host "Deploying the license..." -ForegroundColor green
  	}
	copy c:\temp\license.cxl c:\CxSAST\Licenses\license.cxl
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

# check if needs to be registered with a manager
if (($null -eq $env:sast_server) -or ($null -eq $env:sast_admin) -or ($null -eq $env:sast_adminpwd) -or ($env:sast_server -eq '_') -or ($env:sast_admin -eq '_') -or ($env:sast_adminpwd -eq '_')) {
    Write-Host "CxSAST server name, admin user name or password is not specified. Will not registers this engine."  -ForegroundColor yellow
} else {
# Add to the list of available engines
    Write-Host "Reviewing CxSAST Engine registration with $env:sast_server..."

    #$person = @{username='admin@cx';password='admin'}
    #$admin=(convertto-json $person)  
    $admin="{username:'$env:sast_admin',password:'$env:sast_adminpwd'}"
    try {
       $JSONResponse=Invoke-RestMethod -uri http://$env:sast_server/cxrestapi/auth/login -method post -body $admin -contenttype 'application/json' -sessionvariable sess
    } catch { 
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        throw "Could not authenticate" 
    }
    # grab the token
    $headers=@{"CXCSRFToken"=$sess.Cookies.GetCookies("http://$env:sast_server/cxrestapi/auth/login")["CXCSRFToken"].Value}
    # get the list of all configured engines
    try { 
       $JSONResponse=invoke-restmethod -uri http://$env:sast_server/cxrestapi/sast/engineservers -method get -contenttype 'application/json' -headers $headers -WebSession $sess
    } catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        throw "Error listing servers" 
    } 
    # iterate over the names of the servers
    $addnew=$true
    foreach($engine in $JSONResponse) {
       if ($engine.name -eq 'Localhost'){
    	Write-Host "Localhost engine is registered. You might want to remove it." -ForegroundColor yellow
       }
       if ($engine.name -eq $(hostname)){
    	Write-Host "$(hostname) is already registered"
    	$addnew=$false
    	break	
       }
    }
    # see if we need to add ourselves
    if ($addnew) {
       Write-Host "Registering the CxSAST Engine $(hostname)..."
       $engine='{"name":"'+$(hostname)+'","uri":"http://'+$(hostname)+'/CxSourceAnalyzerEngineWCF/CxEngineWebServices.svc","minLoc":0,"maxLoc":99999999,"isBlocked":false}'
       try { 
       	$JSONResponse=Invoke-RestMethod -uri http://$env:sast_server/cxrestapi/sast/engineservers -method post -body $engine -contenttype 'application/json' -headers $headers -WebSession $sess
       } catch {
       	Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
       	Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
       	throw "Could not register"
       }
    } 
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
