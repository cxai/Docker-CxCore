# CxSAST on a Docker platform
A modular, fast and up-to-date environment for running Checkmarx Security Application Testing Framework inside Docker containers.

* You can scale up or down by adding and removing engine containers. Engines self-add themselves into the scan manager configuration.
* Orchestrated startup and shutdown through a docker swarm, to ensure parts come up in a proper way and stay up
* Database is stored in a docker volume that can be backed up and swapped for a different DB at any time
* A Web GUI controller for all components, networks and volumes

It consists of 4 images:
* CxSAST Manager - Scan, job and system managers
* CxSAST Portal - Web UI
* CxSAST Engine - Scan engine
* MSSQL Express - A custom build of the microsoft's linux mssql server with telemetry disabled

This is an *unnoficial*, unsupported development release not intended for production.
The build *does not* contain the Checkmarx installer or the license required to run CxSAST. You will need to download, unzip the installer separately and get the license before it can run. Read more in the build section.

 If you are looking for the containers for various systems that integrate with Checkmarx SAST look [here](https://github.com/cxai/Docker-CxIntegrations).

 CxSAST runs inside docker containers based off a Microsoft's Windows Server Core image, with telemetry disabled by default.
 To run these containers on a Linux host you will need a VM with Docker like [this one](https://github.com/alexivkin/windows_2016_core)

## How to use it
First you need build the images required to run CxSAST. They are not posted on docker hub. The build procedure is fully documented in [build.md](build.md).

Running CxSAST in containers is best done with the help of a docker swarm orchestrator. You can also start them up manually .Detailed description is in [run.md](run.md)

More internal development notes, troubleshooting and how-tos are in [dev-and-todo.md](dev-and-todo.md)

## Containers
Linux containers:
* CxBuilder - A build-time helper container. For now this is just a web server, serving whatever is in a volume mapped to /www folder. It is not used at run time.
* CxDB - The latest image of Microsoft SQL Linux server with telemetry turned off and pre-configured as the Express version.
* Portainer - Management and visualization GUI for the docker swarm setup, created from the portainer/portainer image. Optional.

Windows containers:
* CxEngine - Checkmarx engine docker container. The actual code scanner.
* CxManagers - Checkmarx scan, job and system managers controlling the Engines
* CxPortal - Checkmarx web interface with IIS

It is possible to run CxDB and CxBuilder as a windows container. For more details see the build instructions

## Notes
* This setup is tested with CxSAST 8.5 and 8.6, docker version 18.01.0-ce for linux/amd64 and 17.10.0-ce for windows/amd64
* No traffic is encrypted. It's a demo system after all.
* The DB IP and passwords are baked into the images at the build time. If the hostname name or the SA password for your DB changes after the initial build you would need to replace C:\CxSAST\Configuration\DBConnectionData.config on cx_managers or rebuild the images.
* Names of the cxdb and cxmanager hosts are hardcoded into the builds. You could however change names of the engines.

## Maintenance

### Managing with portainer.io
`docker run --name portainer -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer`

### Backing up the DB
```
docker stop cxdb
docker run --rm -v cxdb:/from -v cxdb-backup:/to alpine ash -c "cp -av /from/* /to/"
docker start cxdb
```
* Create a container attached to cx8.5db-fresh.

This will ensude that the db empty copy is not removed when `docker system prune` is run

`docker run --name cxdbmgr -v cx8.5db-fresh:/fresh alpine`
Note though that if you remove all stopped volumes this will release the volume to be available for pruning

### Reseting to a blank db
This will refresh the data and create a data refresher container. This will also bind cxdb-fresh volume to ensure it is not gone on docker volume purge.

```
docker stop cxdb
docker run --name cxdatarefresh -v cxdb-fresh:/from -v cxdb:/to alpine ash -c "cp -av /from/* /to/"
docker start cxdb
```

Latter you can just re-run this container every time new db is needed and start sql back up
```
docker stop cxdb
docker start cxdatarefresh
docker start cxdb
```

# References
* [Docker Swarm mode](https://docs.docker.com/get-started/part4)
* [Docker Swarm Tutorial](https://docs.docker.com/engine/swarm/swarm-tutorial/)
* [Docker storage drivers](https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/#sharing-promotes-smaller-images)
* [Deploying across mulitple hosts](https://docs.docker.com/engine/swarm/#feature-highlights)
* [Services, swarms and stacks](https://docs.docker.com/get-started/part5/)
* [Swarm example](https://github.com/docker/labs/blob/master/beginner/chapters/votingapp.md)_
* [Swarm networking](https://docs.docker.com/engine/swarm/networking/)
