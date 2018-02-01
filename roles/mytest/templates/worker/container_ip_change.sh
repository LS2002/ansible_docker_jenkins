#!/bin/bash

if [[ $# -lt 3 ]]; then
    echo "Usage: /local/mytest/worker/container_ip_change.sh <change-ip-every-x-seconds> <ip-pool-size-for-each-container> <stop-ip-change-at-X-cycle-0-for-infinite>"
    exit 0
fi

lock_flag=/tmp/container_hostname.lock
if ! mkdir ${lock_flag} 2>/dev/null; then
    echo "Script already running!"
    exit 0
fi

trap "rm -rf ${lock_flag}; exit" INT TERM EXIT

###########################################################################################
# Run:  ssh root@vm-host bash /local/mytest/worker/container_ip_change.sh 30 10 0 &       #
# Kill: ssh root@vm-host pkill -f "/local/mytest/worker/container_ip_change.sh"           #
###########################################################################################

frequency=$1
shift
size=$1
shift
end=$1
shift

containers=($(docker ps --format "{{ '{{' }}.ID{{ '}}' }}_{{ '{{' }}.Names{{ '}}' }}"))
ip_list_used=($(docker inspect --format="{{ '{{' }}range .NetworkSettings.Networks{{ '}}' }}{{ '{{' }}.IPAddress{{ '}}' }}{{ '{{' }}end{{ '}}' }}" $(docker ps -aq)))
ip_list_all=($(nmap -sL {{ instance_subnet }} | grep "Nmap scan report" | awk '{print $NF}'| awk "NR>2{print $1}"))

for ip_to_delete in ${ip_list_used[@]}; do
    ip_list_all=(${ip_list_all[@]/$ip_to_delete})
done

let ip_range_total="$size * {{ amount_per_host }}"
counter_ip=1
for ip_to_keep in ${ip_list_all[@]}; do
    ip_list_static+=($ip_to_keep)
    ((counter_ip++))
    if [[ $counter_ip -gt $ip_range_total ]]; then
        break
    fi
done

{% raw %}
ip_list_len=${#ip_list_static[@]}
{% endraw %}

if [[ $ip_list_len -lt $ip_range_total ]]; then
    let acceptable_size="ip_list_len / {{ amount_per_host }}"
    echo "Pool size ${size} is too large for subnet {{ instance_subnet }}, make it less than ${acceptable_size}."
    exit 1
fi

mkdir -p temp

counter_cycle=1
while [[ ${end} -eq 0 || ${counter_cycle} -le ${end} ]]; do
    counter_container=1
    for container in ${containers[@]}; do
        container_id=$(echo ${container} |awk -F'_' '{print $1}')
        let next_ip_id="($counter_container - 1) * $size + $counter_cycle % $size - 1"
        next_ip=${ip_list_static[$next_ip_id]}
        temp_script="temp/${container}.sh"
        echo "docker network disconnect mytest_network ${container_id}" > ${temp_script}
        echo "docker network connect --ip=${next_ip} mytest_network ${container_id}" >> ${temp_script}
        bash ${temp_script} &
        ((counter_container++))
    done
    sleep ${frequency}
    ((counter_cycle++))
done

rm -rf ${lock_flag}
