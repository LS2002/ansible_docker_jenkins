#!/bin/bash

unset http_proxy

python {{ mytest_dir}}/worker/run_test_script.py --type {{ test_type }} --path {{ mytest_dir }}/result {{ debug }} &

if [[ "{{ container_os_platform }}" == "Ubuntu" ]]; then

    if [[ {{ fake_process_amount }} -ne 0 ]]; then
        process_count=1
        mkdir -p /tmp
        cd /tmp
        while [[ ${process_count} -le {{ fake_process_amount }} ]]; do
            echo -e '#!/bin/bash\ncounter=0\nwhile true; do' > ${hostname}_${process_count}.sh
            echo -e 'echo sleeping $counter time...' >> ${hostname}_${process_count}.sh
            echo -e "sudo sleep 60\n((counter++))\ndone" >> ${hostname}_${process_count}.sh
            chmod +x ${hostname}_${process_count}.sh
            ./${hostname}_${process_count}.sh &
            ((process_count++))
        done
    fi

    ##########################################################
    # Put other logic here .......
    #
    #
    #
    ##########################################################


    tail -f /dev/null
fi    

if [[ "{{ container_os_platform }}" == "CentOS" ]]; then
    /usr/bin/supervisord -c /usr/local/mytest/supervisord.conf -n
fi    
