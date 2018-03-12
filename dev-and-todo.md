# Todo
## precompile .net code
or configure IIS to do it on startup

To precompile code:
```
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe -v /CxWebClient
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe -v /CxWebInterface
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe -v /CxRestAPI
```

Also can be done from inside the start script once iis running with wget - but then it would not be prebuilt in the image
```
iisreset; spsv cx*; sasv cx*; Invoke-WebRequest http://localhost/cxwebclient
```


* move url redirect setup from setup to docker so it's prebuilt into the image

* Add build into docker-compose
so it can be built with compose

* Switch to docker secrets for the DB pwd and license, since we are using docker swarm

or reconfigure cxbuilder to host build secrets - zip pwd, license etc
great [methods for storing secrets](https://blog.mikesir87.io/2017/05/using-docker-secrets-during-development/)

    Run a Swarm
    Use secrets in Docker Compose
    Mount secret files manually
    Dynamically create secrets using a “simulator”

https://docs.docker.com/engine/swarm/secrets/#about-secrets

## Add healthcheck to dockerfiles
A healthcheck is a script you define in the Dockerfile, which the Docker engine executes inside the container at regular intervals (30 seconds by default, but configurable at the image and container level).

Make sure your HEALTHCHECK command is stable, and always returns 0 or 1. If the command itself fails, your container may not start.

Healthchecks are also very useful if you have expiry-based caching in your app. You can rely on the regular running of the healthcheck to keep your cache up-to date, so you could cache items for 25 seconds, knowing the healthcheck will run every 30 seconds and refresh them.

Linux:
`HEALTHCHECK --interval=5m --timeout=5s CMD wget http://localhost/cxwebclient || exit 1`

Windows:
```
HEALTHCHECK CMD powershell -command `
    try { `
     $response = iwr http://localhost:80 -UseBasicParsing; `
     if ($response.StatusCode -eq 200) { return 0} `
     else {return 1}; `
    } catch { return 1 }
```

# Howtos

## Stopping services in a swarm
To stop a services roll it redundancy to 0

## Troubleshooting MSSQL on Linux

* Run bash
docker run --rm -h cxdb --name cxdb -e 'ACCEPT_EULA=Y' -e SA_PASSWORD=$sa_password -e 'MSSQL_PID=Express' -p 1433:1433 -v ~/5:/host -v cxdb:/var/opt/mssql -it microsoft/mssql-server-linux bash

* Start server from bash
/opt/mssql/bin/sqlservr

* Remove the DB and start afresh
rm -rf /var/opt/mssql/*
/opt/mssql/bin/sqlservr

* Testing creatomg the DB with an SQL load

```
docker run --rm -it -e ACCEPT_EULA=Y -v c:/vagrant:c:/temp microsoft/mssql-server-windows-express sqlcmd -S 192.168.1.15 -U sa -P password -Q 'drop database CxDB'
docker run --rm -it -e ACCEPT_EULA=Y -v c:/vagrant:c:/temp microsoft/mssql-server-windows-express sqlcmd -S 192.168.1.15 -U sa -P password -e -i 'c:\temp\DBInit.txt' -o 'c:\temp\logfile'
```

or you can doing by first jumping into the container

`docker run --rm -it -e ACCEPT_EULA=Y -v c:/vagrant:c:/temp microsoft/mssql-server-windows-express powershell`

then

```
sqlcmd -S 192.168.1.15 -U sa -P password  -e -i .\DBInit.txt -o out.w2l
sqlcmd -S 192.168.1.15 -U sa -P password  -e -Q 'drop database CxDB'
```

## Injecting a test service into the swarm
```
docker service create --name dbtest --network cx_default -e ACCEPT_EULA=Y microsoft/mssql-server-windows-express
docker exec -it dbtest powershell
```

## Rest API with curl
```
curl -X POST "http://192.168.50.4:8080/CxRestAPI/auth/login" -H "accept: application/json;v=1.0" -H "Content-Type: application/json;v=1.0" -d '{ "userName": "admin", "password": "<pwd_here>"}' -c jarjar
curl -X GET "http://192.168.50.4:8080/CxRestAPI/sast/engineServers" -H "accept: application/json;v=1.0" -H 'CXCSRFToken: same value as the cookie' -b jarjar
```

## Microsoft Fusion logging

`reg add HKLM\Software\Microsoft\Fusion /v EnableLog /t REG_DWORD /d 0x1 /f`

## Check for a checksum of a downloaded component to check for errors and guard against supply chain attacks
`if ((Get-FileHash hidgenerator.zip -Algorithm sha256).Hash -ne $env:HID_SHA256) {exit 1} ; \`

## FATAL - System.IO.FileNotFoundException: Could not load file or assembly 'Microsoft.Practices.Unity.resources, Version=4.0.0.0
This is not a Unity error, but something before it - a corrupt database for example

## VM Speed tests

Check out https://serverfault.com/questions/447775/virtualbox-slow-upload-speed-using-nat , https://www.virtualbox.org/manual/ch06.html and https://www.virtualbox.org/manual/ch09.html#nat-adv-settings

* To disable offload
```
Get-NetAdapter
Get-NetAdapterChecksumOffload
Disable-NetAdapterChecksumOffload -Name "adapter"
```

* To disable TCP Chimney feature on the guest adapter
```
netsh int tcp set global chimney=disabled
netsh int tcp set global rss=disabled
netsh int tcp set global netdma=disabled
```

* To display current global TCP settings, use the net shell command:
`netsh int tcp show global`

## Configuring redirects at the build time
They do not work seem to work when run from the docker file.
```
ARG managerhost
RUN stop-service w3svc; \
    stop-service was; \
    Start-Sleep -s 5;
RUN Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter 'system.webServer/proxy' -name 'enabled' -value 'True' ; \
    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules" -name "." -value @{name='ReverseProxyInboundRule1';stopProcessing='True'} ; \
    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule1']/match" -name "url" -value '.*(cxwebinterface/.*)' ; \
    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule1']/conditions" -name "." -value @{input='{CACHE_URL}';pattern='^(https?)://'} ; \
    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule1']/action" -name "url" -value '{C:1}://$env:managerhost/{R:1}' ; \
    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule1']/action" -name "type" -value "Rewrite" ; \
    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules" -name "." -value @{name='ReverseProxyInboundRule2';stopProcessing='True'} ; \
    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule2']/match" -name "url" -value '.*(cxrestapi/.*)' ; \
    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule2']/conditions" -name "." -value @{input='{CACHE_URL}';pattern='^(https?)://'} ; \
    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule2']/action" -name "url" -value '{C:1}://$env:managerhost/{R:1}' ; \
    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='ReverseProxyInboundRule2']/action" -name "type" -value "Rewrite" ;
```

## Installing components required for the distributed installation
External Cache 1.1, URL Rewrite 2.1 and Request Router 3.0

Alternative method, installing through webpi (in the dockerfile):

```
Create-Item c:/msi -Type Directory
Invoke-WebRequest 'http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi' -OutFile c:/msi/WebPlatformInstaller_amd64_en-US.msi
Start-Process 'c:/msi/WebPlatformInstaller_amd64_en-US.msi' '/qn' -PassThru | Wait-Process
cd 'C:/Program Files/Microsoft/Web Platform Installer'; .\WebpiCmd.exe /Install /Products:'UrlRewrite2,ARRv3_0' /AcceptEULA /Log:c:/msi/WebpiCmd.log
```
URL Rewrite 2.0 is at https://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi

## Swarm networking and windows
Endpoint_mode: dnsrr is a limitation of the windows docker right now, The VIP mode is more flexible, but does not work yet:
https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/swarm-mode
About VIP and the service mesh - https://docs.docker.com/engine/swarm/ingress/
About DNSRR - https://docs.docker.com/engine/swarm/networking/#configure-service-discovery
Ports are published to the node host because of the use of dnsrr. Read about the limitations here:
https://docs.docker.com/engine/swarm/services/#publish-a-services-ports-directly-on-the-swarm-node
More documentation on that issue - https://github.com/docker/swarmkit/issues/1429

