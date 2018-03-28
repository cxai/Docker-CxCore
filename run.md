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

## Run using a Docker Swarm

#### Create a swarm if one was not created during the build process
* On the Linux docker host run

`docker swarm init --advertise-addr <linux docker IP from private net with win VM>  --listen-addr <same ip>`

* Join the windows node into the swarm

`docker -H tcp://windowsip swarm join --token SWMTKN-1-tockenheretockenheretockenhere <linux docker IP>:2377`

* Check to make sure the node has joined from the Linux host

`docker node ls`

#### Configure the stack

Set the admin password to match the one in the docker-compose.yml
```
docker run -h cxdb --name cxdb -e SA_PASSWORD=$sa_password -p 1433:1433 -v cxdb:/var/opt/mssql -d cxai/cxdb
docker exec -it cxdb /opt/mssql-tools/bin/sqlcmd -U sa -P $sa_password  -Q "UPDATE [CxDB].[dbo].Users SET Password = 'hlTgLz69abv2jGHWAyj57N8MO3K4L8uBY93mEe0K3JE=', SaltForPassword = 'nTwTPeNHlHdhcxk0IXapiQ==', IsAdviseChangePassword = 0 WHERE username='admin@cx'"
docker stop CxDB
```

#### Deploy the stack

`docker stack deploy -c docker-compose.yml cx`

## Run containers manually

The commands below will run containers from the images without removing them after stop. This way you can start the stopped containers later from where they were stopped.
This allows you to use the cached pre-compiled aspx code on the portal and pre-deployed license on all containers. Start them with a `docker start` command.

#### Start the db on the Linux docker host

`export sa_password=<your password here>`

`docker run -d -h cxdb --name cxdb -e SA_PASSWORD=$sa_password -p 1433:1433 -v cxdb:/var/opt/mssql cxai/cxdb
`

#### Start portainer manually (optional)

`docker run --name portainer --rm -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer`

#### Switch to windows docker host

`export DOCKER_HOST=tcp://<windows docker host ip>`

#### Start the managers

`docker run --name manager --network build-net -d -v cxlicense:c:/temp -e sast_db=db cxai/cxmanagers`

Verify that they started correctly

`docker logs manager`

Note, you can ignore the license errors if the services started correctly. The errors come from the autostart during the build process. The logs were kept as is in case there are more serious errors.

#### Start the portal

`docker run --name portal -d -v cxlicense:c:/temp -p 80:80 -p 443:443 --network build-net -e sast_manager=manager cxai/cxportal`

#### Access portal to set admin passwords
Login to the manager and set the admin password.
http://<windows docker host ip>/CxWebClient/

#### Start the engine

`docker run --name engine1 -h engine1 -d -v cxlicense:c:/temp --network build-net -e sast_server=manager -e sast_admin=<admin name> -e sast_adminpwd=<admin password>  cxai/cxengine`

You could start more engine at this point if you need to. -h is the host name, so the manager has a readable name to address the engine by.

## Test

Browse to http://<windows docker host ip>/CxWebClient
