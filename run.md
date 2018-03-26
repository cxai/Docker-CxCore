# Running CxSAST on Docker containers
This deployment runs and orchestrated as a docker swarm. To simplify swarm management portainer.io is built into the swarm. Docker swarm is used since docker compose does not not support deploying to multiple docker nodes.

You could run also it manually, although it's a little tedious. The manual run is described in the appropriate section below.

To run or build containers on a Linux host you will need a VM with Docker like [this one](https://app.vagrantup.com/StefanScherer/boxes/windows_2016_docker). It needs to be configured as described in the build.md/Notes section.

## Generate the license

This step only needs to be done once.

#### Get the HID

`docker run --rm -it cxai/cxmanagers`

#### Get the license for the provided HID

Talk to your friendly Checkmarx support person if you do not know how

#### Save the license into a docker volume

First make the license available to the docker server by place it into the c:/vagrant folder on the windows docker host. Then run the following commands to copy the license file into the license volume on the windows docker host

`docker run --rm -v c:/vagrant:c:/from -v cxlicense:c:/to microsoft/nanoserver cmd /c 'copy c:\from\license.cxl c:\to\'`

The reason the license needs to be mounted into c:/temp and copied by start.ps1 to c:/CxSAST/Licenses/, instead of mounting it directly to c:/CxSAST/Licenses/ is because the engine can't handle relative links for the license. I.e it does not find it in c:/CxSAST/Licenses/

## Run using a docker swarm

#### Create a swarm. On the linux docker host run

`docker swarm init`

#### Join the windows node into the swarm

```
export DOCKER_HOST=tcp://windowsip
docker swarm join --token SWMTKN-1-tockenheretockenheretockenhere linuxip:2377
```

#### Check to make sure the node has joined

Run the following on the swarm master (linux docker)

`docker node ls`

### Start the swarm

`docker swarm deploy -c docker-compose.yml cx`

## Run containers manually

The commands below will run containers from the images without removing them after stop. This way you can start the stopped containers later from where they were stopped.
This allows you to use the cached pre-compiled aspx code on the portal and pre-deployed license on all containers. Start them with a `docker start` command.

#### Start the db on the linux docker host
```
export sa_password=<your password here>
docker run -d -h cxdb --name cxdb -e SA_PASSWORD=$sa_password -p 1433:1433 -v cxdb:/var/opt/mssql cxai/cxdb
```

Switch to windows docker host

`export DOCKER_HOST=tcp://windowsip`

#### Start the managers

`docker run --name manager -d -v cxlicense:c:/temp cxai/cxmanagers`

Verify that they started correctly

`docker logs manager`

Note, you can ignore the license errors if the services started correctly. The errors come from the autostart during the build process. The logs were kept as is in case there are more serious errors.

#### Start the portal

`docker run --name portal -d -v cxlicense:c:/temp -p 80:80 -p 443:443 cxai/cxportal`

#### Access portal to set admin passwords
Forward port 80 from the windows docker guest to the host and access it
http://localhost:8000/CxWebClient/
Set the admin password.

#### Start the engine

`docker run --name engine1 -d -v cxlicense:c:/temp cxai/cxengine`

#### Start portainer manually (optional)

`docker run --name portainer --rm -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer`

## Test

Browse to http://192.168.50.4/CxWebClient
