#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo "Usage: bash run_mytest.sh <jenkins-variable-txt-file>"
  exit 0
fi

ulimit -n 65536

source $1

test_time_start=`date +'%s'`
container_os_platform=$(echo $container_platform|cut -d- -f1)
#======================================================================================
if [[ "$task_name" = "Reboot_Only" ]]; then
  echo "::::Rebooting all VMs"
	file=${WORKSPACE}/mytest/inventory/$inventory
	hosts=`awk "NR>$(eval "awk '/"${worker_group_name}"/{print NR}'" $file){print}" $file|awk '{print $3}' | awk -F"=" '{print $2}'`
	for host in $hosts;do
    ssh root@$host reboot &
	done
  echo "::::Reboot Done!"
  exit 0
fi
#======================================================================================
echo "::::Changing Strategy by removing last line from yaml"
cd ${WORKSPACE}/mytest/playbooks/
awk "NR>=1 && NR<$(expr $(awk '{n+=1} END {print n}' mytest.yml))" mytest.yml > temp.yml && mv temp.yml mytest.yml
echo "  $strategy" >> mytest.yml
#======================================================================================
if [[ "$test_type" = "upgrade" ]]; then
	test_version=$(ssh user@$ui_server "find /local/binaries -type f -name '*pattern*'|sort -n -t . -k 4|tail -n 2|head -n 1|cut -d/ -f5|cut -d- -f3")
    if [[ "$test_version" = "" ]]; then
    	echo "::::Not found old binary on ${ui_server_name}"
      exit 1
    fi
else
    test_version=$ui_server_sw_version
fi
#======================================================================================
echo "::::Changing inventory according to selected value"
cd ${WORKSPACE}/mytest/inventory/
file=$inventory
inventory_path=${WORKSPACE}/mytest/inventory/$inventory
line_begin=$(eval "awk '/"${worker_group_name}"/{print NR+1}'" $file)
line_end=$(awk '{n+=1}END{print n}' $file)
line_total=$(( $line_end-$line_begin+1 ))
line_current=$line_begin
amount_per_host=$(awk "NR==$line_begin {print}" $file|cut -d'=' -f7|cut -d' ' -f1)
amount_per_loop=$(awk "NR==$line_end {print}" $file|cut -d'=' -f7|cut -d' ' -f1)

if [[ "$test_amount" = "100" ]]; then
	amount=100
	let line_keep="100 / $amount_per_host + 1"
elif [[ "$test_amount" = "500" ]]; then
	amount=500
	let line_keep="500 / $amount_per_host + 1"
elif [[ "$test_amount" = "20k" ]]; then
	amount=20000
	line_keep=$line_total
else
	amount=750
	line_keep=$line_total
fi

let loops="$amount / $amount_per_loop + 1"
echo "::::loops=$loops"
echo loops=$loops >> ${WORKSPACE}/var_mytest.txt
container_amount_value=$amount
container_amount_value=$amount >> ${WORKSPACE}/var_mytest.txt
if [[ $line_keep -lt $(( $line_end-$line_begin )) ]]; then
	echo "::::Modifying $inventory per actual amount $amount"
	awk "NR>=1&&NR<$line_begin" $file > temp.inventory

  counter=1
	step_regular=$(( $line_total/$line_keep ))
	step_rounded=$(( ($line_total+$line_keep-1)/$line_keep ))

	while [ $counter -le $line_keep ]; do
    awk "NR==$line_current" $file >> temp.inventory
    if [ $(( $line_end-$line_current+$counter )) -eq $line_keep ]; then
      awk "NR>=$line_current&&NR<=$line_end" $file >> temp.inventory
      break
    fi
    
    ((counter++))
    
    if [ $step_regular -eq $step_rounded ]; then
      line_current=$(( line_current+$step_regular ))
    else
      if [ $(( $counter%2 )) -eq 0 ]; then
        line_current=$(( line_current+$step_rounded ))
      else
        line_current=$(( line_current+$step_regular ))
      fi
    fi
  done

  mv temp.inventory $file
fi

#=========================================================================================
# Run test
cd ${WORKSPACE}/mytest
ansible-playbook -i inventory/$inventory playbooks/mytest.yml \
                         -s -e run=true --limit server \
                         --extra-vars \
                         "mytester_server_name=${mytester_server_name}
                          mytester_server_user=${mytester_server_user}
                          task_name=${task_name}"
test_time_total=$((`date +'%s'` - $test_time_start))
echo "::::Test is done and it takes $test_time_total seconds ($(date -d@$test_time_total -u +%H:%M:%S))"



