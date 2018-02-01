#!/bin/bash

ulimit -n 65536

if [[ "{{ use_docker_container }}" = "true" ]]; then

    docker_image={{ mytest_server_name }}:5000/test_{{ ui_server_name }}
    if [[ {{ loop_counter }} -le {{ loop_start }} && "{{ force_pull_images }}" == "true" ]]; then
        docker pull ${docker_image}
    fi

    if [[ $(docker network ls | grep mytest_network) ]]; then
        docker network rm mytest_network
    fi
    docker network create --subnet={{ instance_subnet }} mytest_network

    let x="{{ instance_start }} + ({{ loop_counter }} - 1) * {{ amount_per_loop }}"
    let y="{{ instance_end }} + ({{ loop_counter }} - 1) * {{ amount_per_loop }}"

    let ip_range_min="({{ loop_counter }} - 1) * {{ amount_per_host }}"
    let ip_range_max="{{ loop_counter }} * {{ amount_per_host }}"

    static_ip_list=($(nmap -sL {{ instance_subnet }}|grep "Nmap scan report"|awk '{print $NF}'| awk "NR>2{print $1}"|awk "NR>=$ip_range_min&&NR<=$ip_range_max{print $1}"))

    host_id=$(hostname|tail -c 5)
    counter=1
    host_ip=$(ifconfig|grep "192\.168"|awk '{$1=$1;print}'|cut -d: -f2|cut -d" " -f1)

    for cid in `seq -f %04g ${x} ${y}`
    do

        unique_id="{{ unique_id }}"
        container_name={{ container_hostname }}-${host_id}-${cid}-${unique_id}

        if [ $((counter%{{ container_batch_amount }})) -eq 0 ]; then
            sleep {{ sleep_between_batch }}
        fi

        if [[ "{{ special_test }}" = "true" && -e "{{ mytest_dir }}/special_test/ip.txt" ]]; then
            st_amount=$(awk 'END{print NR}' {{ mytest_dir }}/special_test/ip.txt)
            let hosts_needed_per_replicate="(${de_amount} + {{ amount_per_host }}) / {{ amount_per_host }}"

            let line_number="(({{ hid }} -1) % $hosts_needed_per_replicate) * {{ amount_per_host }} + $counter"
            if [[ ${line_number} -gt ${de_amount} ]]; then
                line_number=$(expr ${line_number} % ${de_amount})
            fi

            container_name={{ container_hostname }}-${host_id}-${cid}-${unique_id}-${special_test_pattern}
            networks=$(docker network ls -f 'driver=bridge'|awk 'NR>1{print $2}')
            if ! [[ "${networks[@]}" =~ "$mytest_subnet" ]]; then
                docker network create --subnet=${st_subnet} ${st_subnet_name}
            fi

        fi

        docker run --privileged --cap-add=NET_ADMIN -t -d --net mytest_network --ip ${static_ip_list[counter-1]}  --hostname ${container_name} --name ${container_name} -v /etc/localtime:/etc/localtime -v {{ mytest_dir}}:{{ mytest_dir}} --log-opt max-size=500m ${docker_image} &


        ((counter++))
    done


    bash {{ mytest_dir }}/docker/docker_utils.sh restart


else

    if [[ "{{ instance_type }}" = "win64" ]]; then
        echo "handling windows vm at here"
    else
        echo "handling debian vm at here"
    fi

fi
