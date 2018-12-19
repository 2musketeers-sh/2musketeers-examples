# Maven spring boot example

There are two modes to run this, `./ci.sh` which runs the build exact like it runs in CI, including downloading the maven artifacts each and every time ;-).

`./run_local.sh` will let you "enter" the build and run arbitary commands, including docker (sibling docker, not docker-in-docker)

## To run

As ci.
```sh
./ci.sh
```

Local dev environment
```sh
./run_local.sh
# in the container
./mvnw install
docker ps
```