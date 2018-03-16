# Building CxSAST on Docker

## Build architecture
The procedure below describes a **cross platform** docker build and uses a Linux host for the DB and portainer and a virtual box [Windows Docker VM](https://app.vagrantup.com/StefanScherer/boxes/windows_2016_docker) for the rest of Checkmarx components. To run or build containers on the Linux host you will need a VM with Docker like [this one](https://github.com/alexivkin/windows_2016_core). It needs to be configured as described in the [Notes](#Notes) section.

You can run everything on just the windows docker host, but you will not be able to use docker swarm and portainer. To do that you will need to change the below procedure to:
* Run [MSSQL Windows container](https://hub.docker.com/r/microsoft/mssql-server-windows-express/). It has slightly different setup from the Linux version. See notes below for more details
* Change bash for the appropriate powershell commands.
* Ignore all the windows-linux host switching.

## Build

#### Build the builder

First you will need to build CxBuilder, put unzipped Checkmarx Installer and the HID generator in the same folder, then build the rest of the docker images. It is necessary do it, so that CxSetup.exe is not included in the layers of the Checkmarx docker images, since `squash` is [not yet working](https://github.com/moby/moby/issues/34565) on windows docker.

CxBuilder is just a web server, bound to a local host and serving content of its own directory. CxBuilder needs to be created only once, the first time you do the build. You can reuse the image in the subsequent builds.

`docker build -t cxai/cxbuilder CxBuilder/`

#### Start the builder to serve the necessary components for Cx builds

Get the latest CxSetup.exe, HidGenerator.zip and save them into the CxBuilder folder. Then run the following from a folder above CxBuilder

`docker run --name cxbuilder --rm -d -p 8000:8000 -v $(pwd)/CxBuilder:/www cxai/cxbuilder`

#### Build the DB container

CxDB is a container based off microsoft/mssql-server-linux, with telemetry disabled by default. You can skip this step and run the microsoft/mssql-server-linux image directly instead if you don't care about M$ sniffing your activities.
Unlike Microsoft's [approach](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-customer-feedback) this image has the proper setting baked into the image.

#### Start the db
Specify a password and run the MSSQL container

```
export sa_password=<your password here>
docker run -h cxdb --name cxdb -e SA_PASSWORD=$sa_password -p 1433:1433 -v cxdb:/var/opt/mssql -d cxai/cxdb
```

The -h is so the server gives it the correct name. Unlike the Windows docker container for MSSQL, the db server name does not come from --name, but from -h. Running the DB contianer for the first time will create the cxdb volume with the actual database.

#### Verify the build environment

Grab linux docker host IP from the VM's private-network interface (vboxnet2). Although you could use dockers native network interface (docker0), VBox outgoing NAT implementation currently has a bug aborting fast data streams, specifically DB creation scripts.
```
export linuxhost=$(ip addr show dev vboxnet2 | grep -w inet | awk '{print $2}' | cut -d '/' -f 1)
```

Connect to the docker on windows and make sure it's working.
```
export DOCKER_HOST=tcp://<windows host ip>
docker version | grep Arch
```

Make sure you can reach the builder from inside the windows docker server
```
docker run --rm microsoft/nanoserver powershell Invoke-WebRequest http://$linuxhost:8000/ -usebasicparsing | grep StatusCode
```

Should show 200

Now make sure the DB is reachable and works. The first time you run the command below will pull in the microsoft/mssql-server-windows-express image

```
docker run --rm -it -e ACCEPT_EULA=Y microsoft/mssql-server-windows-express sqlcmd -S $linuxhost,1433 -U sa -P $sa_password -Q "select name from sys.databases; select @@servername + '\' + @@servicename"
```

It should show four databases and the server name

#### Build Cx managers image

`docker build -t cxai/cxmanagers --build-arg CX_DOWNLOAD_URL=http://$linuxhost:8000/CxSetup.exe --build-arg SQL_SERVER=$linuxhost --build-arg SQL_PWD=$sa_password --build-arg HID_DOWNLOAD_URL=http://$linuxhost:8000/HidGenerator.zip CxManagers`

This will also populate the DB with the default schema. Check the logs on cxdb to make sure the db installation completed successfuly, otherwise you risk having weird startup errors for the Cx managers.

`docker logs cxdb`

Look for fatal errors during the DB creation.

#### Build Cx portal image

`docker build -t cxai/cxportal --build-arg CX_DOWNLOAD_URL=http://$linuxhost:8000/CxSetup.exe --build-arg SQL_SERVER=$linuxhost --build-arg SQL_PWD=$sa_password --build-arg HID_DOWNLOAD_URL=http://$linuxhost:8000/HidGenerator.zip CxPortal`

#### Build Cx engine image

`docker build -t cxai/cxengine --build-arg CX_DOWNLOAD_URL=http://$linuxhost:8000/CxSetup.exe --build-arg SQL_SERVER=$linuxhost --build-arg SQL_PWD=$sa_password --build-arg HID_DOWNLOAD_URL=http://$linuxhost:8000/HidGenerator.zip CxEngine`

#### Stop the builder and the database

```
export DOCKER_HOST=tcp://localhost
docker stop cxbuilder
docker stop cxdb
```

## Notes

### Setting up the docker windows VM host
The docker windows VM needs to have the following configured:
* A second network interface in a private network mode (host-only mode). Simply exposing dockers port through the default NAT interface (2375 to something like 12375) would work for managing remote docker server with a docker client.
However since we are using docker swarm and we can not change what DNS ports that the swarm manager expects, the only alternative is a private network.
* Turn off windows firewall while you are at it from within the guest - `NetSh Advfirewall set allprofiles state off`
* Enable dockerd remote APIs - `echo '{ "hosts": ["tcp://0.0.0.0:2375", "npipe://"] }' | out-file -encoding ascii c:\ProgramData\docker\config\daemon.json`

You could also turn off firewall rules for just the necessary ports:
```
# insecure docker port
if (!(Get-NetFirewallRule | where {$_.Name -eq "Dockerinsecure2375"})) {
    New-NetFirewallRule -Name "Dockerinsecure2375" -DisplayName "Docker insecure on TCP/2375" -Protocol tcp -LocalPort 2375 -Action Allow -Enabled True
}
# swarm ports
if (!(Get-NetFirewallRule | where {$_.Name -eq "Dockerswarm2377"})) {
    New-NetFirewallRule -Name "Dockerswarm2377" -DisplayName "Docker Swarm Mode Management TCP/2377" -Protocol tcp -LocalPort 2377 -Action Allow -Enabled True
}
if (!(Get-NetFirewallRule | where {$_.Name -eq "Dockerswarm7946"})) {
    New-NetFirewallRule -Name "Dockerswarm7946" -DisplayName "Docker Swarm Mode Node Communication TCP/7946" -Protocol tcp -LocalPort 7946 -Action Allow -Enabled True
}
if (!(Get-NetFirewallRule | where {$_.Name -eq "Dockerswarm7946udp"})) {
    New-NetFirewallRule -Name "Dockerswarm7946udp" -DisplayName "Docker Swarm Mode Node Communication UDP/7946" -Protocol udp -LocalPort 7946 -Action Allow -Enabled True
}
if (!(Get-NetFirewallRule | where {$_.Name -eq "Dockerswarm4789"})) {
    New-NetFirewallRule -Name "Dockerswarm4789" -DisplayName "Docker Swarm Overlay Network Traffic TCP/4789" -Protocol tcp -LocalPort 4789 -Action Allow -Enabled True
}
```

### Running everything on a docker windows host

To change to the Windows version of the MSSQL Express container run it with the following options:
```
docker run --name sqlexpress -e 'ACCEPT_EULA=Y' -e 'MSSQL_PID=Express' -e 'MSSQL_SA_PASSWORD=password' -p 1433:1433 -e attach_dbs="[{'dbName':'CxDB','dbFiles':['C:\\DATA\\CxDB.mdf','C:\\DATA\\CxDB_log.ldf']},{'dbName':'CxActivity','dbFiles':['C:\\DATA\\CxActivity.mdf','C:\\DATA\\CxActivity_log.ldf']]
-v ./data:C:/DATA -d microsoft/mssql-server-linux:2017-latest
```

You will need to grab for CxDB an CxActivities from the mssql image after the CxManager the installation
