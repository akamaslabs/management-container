#!/bin/bash

docker-compose up -d
sleep 2
curr_password=$(docker-compose logs management-container | grep Password | cut -d ':' -f 2 | sed 's/ //')
container_id=$(docker ps | grep management-container | cut -d ' ' -f 1)
docker cp test-remote-ssh.sh ${container_id}:/tmp/
docker exec $container_id /tmp/test-remote-ssh.sh "$curr_password"
if [ $? -eq 0 ]; then
	echo "Test PASSED"
else
	echo "Test FAILED"
	exit 1
fi
#docker-compose down
