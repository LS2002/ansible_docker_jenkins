#!/bin/bash

if [[ $# -lt 1 ]]; then
    echo "Usage: docker_utils.sh registry|clean <container|image|all>|create|list <worker-groupname> <inventory-path>|restart"
    exit 0
fi

if [[ "$1" = "clean" ]]; then
    if [[ {{ loop_counter }} -eq {{ loop_start }} ]]; then
        if [[ "$2" = "container" || "$2" = "all" ]]; then
            containers=($(docker ps -a|grep -v IMAGE|awk '{print $1}'))
            for container in "${containers[@]}"; do
                docker rm -f $container
            done
        fi

        if [[ "$2" = "image" || "$2" = "all" ]]; then
            images=($(docker images|grep -v IMAGE|awk '{print $3}'))
            for image in "${images[@]}"; do
                docker rmi -f $image
            done
        fi

        if [[ "$2" = "network" || "$2" = "all" ]]; then
            networks=($(docker network ls -f 'driver=bridge' | awk 'NR>1{print $2}' | grep {{ container_hostname }}))
            for network in "${networks[@]}"; do
                docker network rm $network
            done
        fi
    fi
fi

if [[ "$1" = "restart" ]]; then
    docker ps -a -q -f status=created -f status=exited | xargs -I {} docker start {} &
fi

if [[ "$1" = "registry" ]]; then
    registry_name=$(docker ps | grep -v NAMES | awk -F'tcp   ' '{print $2}')
    if [[ "$registry_name" = *"{{ registry_name }}"* ]];then
        docker rm -f $(docker ps -qa)
    fi
    docker run -d -p 5000:5000 --restart=always --name {{ registry_name }} -v {{ mytest_dir }}/certs:/certs -v {{ registry_dir }}:/var/lib/registry -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key registry:2
fi

if [[ "$1" = "create" ]]; then
    cd {{ mytest_dir }}/docker
    docker build -t test_{{ unique_name }} -f {{ dockerfile }} .
    docker tag test_{{ unique_name }} {{ mytest_server_name }}:5000/test_{{ unique_name }}
    docker push {{ mytest_server_name }}:5000/test_{{ unique_name }}
fi

if [[ "$1" = "list" ]]; then
    worker_group_name=$2
    inventory=$3
    line_begin=$(eval "awk '/"${worker_group_name}"/{print NR+1}'" ${inventory})
    line_end=$(awk '{n+=1}END{print n}' ${inventory})
    workers=($(awk "NR>=$line_begin && NR<=$line_end" ${inventory} | awk -F'=' '{t=$1" "$3; print t}'|awk -F' ' '{t=$1"_"$3; print t}'))
    containers_in_ui=$(python {{ mytest_dir}}/server/server_utils.py --function list_containers_on_ui)
    containers_in_server=$(awk 'NR>1{print $0}' {{ mytest_dir }}/result/mytest_result*)
    for worker in ${workers[@]}; do
        worker_name=$(echo ${worker}|awk -F'_' '{print $1}')
        worker_ip=$(echo ${worker}|awk -F'_' '{print $2}')
        echo "---------------------------------------------------------------"
        echo "$worker_name $worker_ip"
        echo "$(ssh -o StrictHostKeyChecking=no root@${worker_ip} docker info|grep -E 'Containers|Running|Created|Exited')"
        echo "..............................................................."
        echo "Containers missing in worker result: $(ssh -o StrictHostKeyChecking=no root@$worker_ip ls -1 {{ mytest_dir }}/result/ | awk -F'-' '{print $3}' | awk '$1!=p+1 {result=result" "p+1}{p=$1}END{print result}' | awk 'NR>1')"
        echo "..............................................................."
        containers_created=($(ssh -o StrictHostKeyChecking=no root@$worker_ip "docker ps -a --format '{{ '{{' }}.ID{{ '}}' }} {{ '{{' }}.Names{{ '}}' }}'" | awk -F' ' '{print $1"_"$2}'))
        containers_missed_in_ui=()
        containers_missed_in_server=()
        counter_ui=0
        counter_server=0
        for container in ${containers_created[@]}; do
            container_name=$(echo $container|awk -F'_' '{print $2}')
            if ! [[ $containers_in_ui =~ $container_name ]]; then
                containers_missed_in_ui+=("$container")
                ((counter_ui++))
            fi
            if ! [[ $containers_in_server =~ $container_name ]]; then
                containers_missed_in_server+=("$container")
                ((counter_server++))
            fi
        done
        echo "Containers created but missing in UI: $counter_ui ${containers_missed_in_ui[@]}"
        echo "..............................................................."
        echo "Containers appear in UI but missing in server result: $counter_server ${containers_missed_in_server[@]}"
    done
fi
