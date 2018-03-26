# CxSAST on a Docker platform
A modular, fast and up-to-date environment for running Checkmarx Static Application Security Testing solution as Docker containers.

## About
This is an **unofficial**, unsupported development release not intended for production. It is a proof of concept, to show that it's indeed possible to run it on Windows Docker Containers. It also has the following features:

* Cloud friendly - scalable and relocatable
* You can scale up or down by adding and removing engine containers. Engines self-add themselves into the scan manager configuration.
* Orchestrated startup and shutdown through a docker swarm, to ensure parts come up in a proper way and stay up
* Database is stored in a docker volume that can be backed up and swapped for a different DB at any time
* A Web GUI controller for all components, networks and volumes

Following the Docker best practice CxSAST is split up into functional components - CxEngine, CxManagers, CxPortal. MSSQL is running in a separate container as well. This approach affords better scalability and HA, at a small cost of the networking overhead. It also conforms to the [Distributed Architecture](https://checkmarx.atlassian.net/wiki/spaces/KC/pages/79921199/Distributed+Architecture).

Images:
* CxSAST Manager - Scan, job and system managers
* CxSAST Portal - Web UI
* CxSAST Engine - Scan engine
* MSSQL Express - A custom build of the microsoft's linux mssql server with telemetry disabled

If you are looking for the containers for various systems that integrate with Checkmarx SAST look [here](https://github.com/cxai/Docker-CxIntegrations).


The build *does not* contain the Checkmarx installer or the license required to run CxSAST. You will need to download, unzip the installer separately and get the license before it can run. Read more in the build section.

CxSAST runs inside docker containers based off a Microsoft's Windows Server Core image, with telemetry disabled by default.
To run these containers on a Linux host you will need a VM with Docker like [this one](https://app.vagrantup.com/StefanScherer/boxes/windows_2016_docker) from Stefan Scherer.

## How to use it
First you need build the images required to run CxSAST. They are not posted on docker hub. The build procedure is fully documented in [build.md](build.md).

Running CxSAST in containers is best done with the help of a docker swarm orchestrator. You can also start them up manually. Detailed description is in [run.md](run.md).

## Containers
![linux arch](images/diagram.png)

Linux containers:
* CxBuilder - A build-time helper container. For now this is just a web server, serving whatever is in a volume mapped to /www folder. It is not used at run time.
* CxDB - The latest image of Microsoft SQL Linux server with telemetry turned off and pre-configured as the Express version.
* Portainer - Management and visualization GUI for the docker swarm setup, created from the portainer/portainer image. Optional.

Windows containers:
* CxEngine - Checkmarx engine docker container. The actual code scanner.
* CxManagers - Checkmarx scan, job and system managers controlling the Engines
* CxPortal - Checkmarx web interface with IIS

It is possible to run CxDB and CxBuilder as a windows container. For more details see the [build instructions](build.md).

## Notes
* This setup is tested with CxSAST 8.5 and 8.6, docker version 18.01.0-ce for linux/amd64 and 17.10.0-ce for windows/amd64
* No traffic is encrypted. It's a demo system after all.
* The DB IP and passwords are baked into the images at the build time. If the hostname name or the SA password for your DB changes after the initial build you would need to replace C:\CxSAST\Configuration\DBConnectionData.config on cx_managers or rebuild the images.
* Names of the cxdb and cxmanager hosts are hardcoded into the builds. You could however change names of the engines.
* Containers use pretty colors if you run them with -it, even in the detached mode (through `docker logs`)

## Maintenance

### Managing with portainer.io
`docker run --name portainer -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer`

### Backing up the DB
```
docker stop cxdb
docker run --name cxdbbackup -v cxdb:/from -v cxdb-backup:/to alpine ash -c "cp -av /from/* /to/"
docker start cxdb
```
This will also create a container attached to cxdb-backup. This will ensure that the db empty copy is not removed when `docker system prune` is run.

You can later take a DB backup by running
```
docker stop cxdb
docker start cxdbbackup
docker start cxdb
```

Note though that if you remove all stopped volumes this will release the volume which in turn will be available for pruning.

### Reseting to a blank db
This will reset the database to the blank state and create a "data refresher" container. This will also bind cxdb-fresh volume to ensure it is not removed on `docker volume purge`.

```
docker stop cxdb
docker run --name cxdbrestore -v cxdb-fresh:/from -v cxdb:/to alpine ash -c "cp -av /from/* /to/"
docker start cxdb
```

Later you can just re-run this container every time a new db is needed
```
docker stop cxdb
docker start cxdbrestore
docker start cxdb
```

### Checking the logs
`docker logs cxcontainer` or `docker logs -f cxcontainer` to trail the logs

### Stopping services in a swarm
To stop a services roll it redundancy to 0

## Todo

* Move url redirect setup from setup in portal to dockerfile so it's prebuilt into the image
* Add build into docker-compose so it can be built with compose
* Switch to docker secrets for the DB pwd and license into the [docker swarm secrets](https://docs.docker.com/engine/swarm/secrets/#about-secrets
) or reconfigure cxbuilder to host build secrets - install file, zip pwd, license etc. Here are great [methods for storing secrets](https://blog.mikesir87.io/2017/05/using-docker-secrets-during-development/)
* Add healthcheck to dockerfiles. A healthcheck is a script you define in the Dockerfile, which the Docker engine executes inside the container at regular intervals (30 seconds by default, but configurable at the image and container level). Make sure your HEALTHCHECK command is stable, and always returns 0 or 1. If the command itself fails, your container may not start. E.g.
`HEALTHCHECK --interval=5m --timeout=5s CMD wget http://localhost/cxwebclient || exit 1`
or powershell
```
HEALTHCHECK CMD powershell -command `
    try { `
     $response = iwr http://localhost/cxwebclient -UseBasicParsing; `
     if ($response.StatusCode -eq 200) {return 0} `
     else {return 1}; `
    } catch {return 1}
```
## Known issues

* When a manager is installed a non-existing engine is configured by default on localhost that needs to be deleted.

# References
* [Docker Swarm mode](https://docs.docker.com/get-started/part4)
* [Docker Swarm Tutorial](https://docs.docker.com/engine/swarm/swarm-tutorial/)
* [Docker storage drivers](https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/#sharing-promotes-smaller-images)
* [Deploying across mulitple hosts](https://docs.docker.com/engine/swarm/#feature-highlights)
* [Services, swarms and stacks](https://docs.docker.com/get-started/part5/)
* [Swarm example](https://github.com/docker/labs/blob/master/beginner/chapters/votingapp.md)
* [Swarm networking](https://docs.docker.com/engine/swarm/networking/)
