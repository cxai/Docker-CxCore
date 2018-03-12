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

## How to use it

First you need build the images required to run CxSAST. They are not posted on docker hub. It's documented [here](build.md).

You could run it manually or via a docker swarm. Look in [here](run.md)

For development howtos and todos look [here](dev-and-todo.md)

## Notes
* Tested with CxSAST 8.5 and 8.6, docker version 18.01.0-ce for linux/amd64 and 17.10.0-ce for windows/amd64
* No traffic is encrypted (it's a demo system after all)
* The DB IP and passwords are baked into the cx images at the build time. If the hostname name or the SA password for your DB changes after the initial build you would need to replace C:\CxSAST\Configuration\DBConnectionData.config on cx_managers or rebuild the images.
* Names of the cxdb and cxmanager hosts are hardcoded into the builds. You could however change names of the engines

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

# Links

[Docker Swarm mode](https://docs.docker.com/get-started/part4)
[Docker Swarm Tutorial](https://docs.docker.com/engine/swarm/swarm-tutorial/)
[Docker storage drivers](https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/#sharing-promotes-smaller-images)
[Deploying across mulitple hosts](https://docs.docker.com/engine/swarm/#feature-highlights)
[Services, swarms and stacks](https://docs.docker.com/get-started/part5/)
[Swarm example](https://github.com/docker/labs/blob/master/beginner/chapters/votingapp.md)_
[Swarm networking](https://docs.docker.com/engine/swarm/networking/)
