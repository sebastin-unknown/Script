if [[ $EUID -ne 0 ]]; then
    echo -e "This script must be run as root ... \e[1;31m[ERROR] \e[0m\n"
    exit 1
else
    cwd=$(pwd)
    dateis=$(date +%d%m%Y)
    end="\n=============================================================================\n"
    end2="\n----------------------------------------------------------------------------\n"
    if [[ -e $cwd/Setup_Report_$dateis.log ]]; then
        rm -f "$cwd/Setup_Report_$dateis.log"
    fi
    touch "$cwd/Setup_Report_$dateis.log"
    file_write="$cwd/Setup_Report_$dateis.log" 
    #file_write=($cwd/Setup_Report_$dateis.log)
    
    if [ -r /etc/os-release ]; then
        os="$(. /etc/os-release && echo -e "$ID")"
    fi

    function file_remove() {
        cd $cwd
        local files_to_remove=(
            "./OS_logs_$dateis.tar.gz"
            "./history_$dateis.log"
            "./top_$dateis.log"
            "./ps_pcpu_$dateis.log"
            "./ps_rss_$dateis.log"
            "./service_logs_$dateis.tar.gz"
            "dfsadmin_$dateis.out"
            "fsck_$dateis.out"
        )
        for file in "${files_to_remove[@]}"; do
            if [[ -e $file ]]; then
                rm -f "$file"
            fi
        done
    }

    function ip_connectivity() {
        if [[ $os == "rhel" ]]; then
            local ip_addresses=$(awk '/core/ {for(i=1;i<=NF;i++) if ($i ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/) print $i}' /DNIF/PICO/podman-compose.yaml)
        else
            local ip_addresses=$(awk '/core/ {for(i=1;i<=NF;i++) if ($i ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/) print $i}' /DNIF/PICO/docker-compose.yaml)
        fi
        local ports=("1443" "8086" "8765")

        echo -e "Testing connection with Core IP($ip_addresses):\n" >> "$file_write"

        for ip in $ip_addresses; do
            echo -e $end2
            for port in "${ports[@]}"; do
                printf "Testing connectivity with %s on port %s\n" "$ip" "$port" >> "$file_write"
                echo -e "$ nc -z -v $ip $port" >> "$file_write"
                nc -z -v "$ip" "$port" &>> "$file_write"
                echo -e $end2
            done
        done
    }
    function hadoop_spark_servers_status() {
        services_os=("spark-master.service" "spark-slave.service" "hadoop-datanode.service")
        for s in "${services_os[@]}"; do 
            echo -e "***** $s *****\n" >> "$file_write"
            systemctl status "$s" | grep -i active >> "$file_write"
            echo -e $end >> "$file_write"
        done
        echo -e "***** QUERY-CORRELATION-REPORT SERVER STATUS *****\n" >> "$file_write"
        ps -aux | grep -i "thrift" >> "$file_write"
        echo -e $end >> "$file_write"
    }

    function dn_service_logs() {
        services_dn=("dn_monitor" "health_reporter" "robocop" "sheepdog" "supervisor_monitor")
        echo -e "***** DATANODE SERVICE LOGS *****\n" >> $file_write
        for s in "${services_dn[@]}"; do 
            echo -e "$s" >> $file_write
            tail /DNIF/DL/log/"$s".log >> $file_write 
            echo -e $end2 >> $file_write
        done
        echo -e $end >> $file_write
    }

    function ad_service_logs() {
        services_ad=("dfs_put" "enrich_process" "eps-governor" "health_reporter" "indexer_process" "log_consumer" "parser_process" "robocop" "sheepdog" "supervisor_monitor")
        echo -e "***** ADAPTER SERVICE LOGS *****\n" >> $file_write
        for s in "${services_ad[@]}"; do 
            echo -e "$s" >> $file_write
            tail /DNIF/AD/log/"$s".log >> $file_write 
            echo -e $end2 >> $file_write
        done
        echo -e $end >> $file_write
    }

    function ad_service_logs_m() {
        services_ad=("dfs_put" "enrich_process" "eps-governor" "health_reporter" "indexer_process" "log_consumer" "parser_process" "robocop" "sheepdog" "supervisor_monitor")
        echo -e "***** ADAPTER SERVICE LOGS for $a *****\n" >> $file_write
        for s in "${services_ad[@]}"; do 
            echo -e "$s" >> $file_write
            tail $a/log/"$s".log >> $file_write 
            echo -e $end2 >> $file_write
        done
        echo -e $end >> $file_write
    }

    function pc_service_logs() {
        services_pc=("eps-governor" "filter_engine" "native_forwarder" "health_reporter" "robocop" "sheepdog" "supervisor_monitor")
        echo -e "***** PICO SERVICE LOGS *****\n" >> $file_write
        for s in "${services_pc[@]}"; do 
            echo -e "$s" >> $file_write
            tail /DNIF/PICO/log/"$s".log >> $file_write
            echo -e $end2 >> $file_write
        done
        echo -e $end >> $file_write
    }

    function co_service_logs() {
        services_mdn=("dn_monitor" "health_reporter" "robocop" "sheepdog" "supervisor_monitor")
        services_co=("api_service" "auto_scheduler" "celery_scheduler" "cluster_api_service" "core_worker" "dispatcher_api_service" "signal_sync" "health_reporter" "robocop" "sheepdog" "supervisor_monitor")
        echo -e "***** MASTER DATANODE SERVICE LOGS *****\n" >> $file_write
        for ms in "${services_mdn[@]}"; do
            echo -e "$ms" >> $file_write
            tail /DNIF/DL/log/"$ms".log >> $file_write
            echo -e $end2 >> $file_write
        done
        echo -e $end >> $file_write
        echo -e "***** CORE SERVICE LOGS *****\n" >> $file_write
        for s in "${services_co[@]}"; do 
            echo -e "$s" >> $file_write
            tail /DNIF/CO/log/"$s".log >> $file_write
            echo -e $end2 >> $file_write  
        done
        echo -e $end >> $file_write
    }

    function host_os_check() {
        echo -e "\n================================Setup Report=================================\n" >> $file_write
        echo -e "***** TIMEDATECTL *****\n" >> $file_write
        timedatectl >> $file_write
        echo -e "***** IP OF THE SERVER ***** \n" >> $file_write
        ifconfig >> $file_write
        echo -e "***** IP ADDR OF THE SERVER ***** \n" >> $file_write
        ip addr show  >> $file_write
        echo -e "***** HOSTNAME ***** \n" >> $file_write
        hostname >> $file_write
        echo -e $end >> $file_write
        echo -e "***** UPTIME OF THE SERVER *****\n" >>$file_write
        uptime -p >>$file_write
        echo -e $end >>$file_write
        echo -e " ***** LAST REBOOT ***** \n" >>$file_write
        last reboot >>$file_write
        echo -e $end >>$file_write
        echo -e "***** DISK DETAILS *****\n" >>$file_write
        df -h >>$file_write
        echo -e $end >>$file_write
        echo -e "***** MEMROY DETAILS  *****\n" >>$file_write
        free -h >>$file_write
        echo -e $end >>$file_write
        echo -e "***** HOST PROXY ***** \n" >>$file_write
        env | grep -i proxy >>$file_write
        echo -e $end >>$file_write
        echo -e "***** UMASK OF THE SERVER ***** \n" >>$file_write
        umask >>$file_write
        echo -e $end >>$file_write
        echo -e "***** SESTATUS ***** \n" >>$file_write
        if [ ! -f "/usr/sbin/sestatus" ]; then
            echo "policycoreutils is not installed" >>$file_write
        else
            sestatus >>$file_write
        fi
        echo -e $end >>$file_write
        echo -e "***** IP OF THE SERVER ***** \n" >>$file_write
        ifconfig >>$file_write
        echo -e $end >>$file_write
        echo -e " ***** CPU DETAILS  ***** \n" >>$file_write
        lscpu >>$file_write
        echo -e $end >>$file_write
        echo -e " ***** NUMBER OF VIRTUAL CPU ****** \n" >>$file_write
        nproc >>$file_write
        echo -e $end >>$file_write
        echo -e " ***** HOST FILE ***** \n" >>$file_write
        cat /etc/hosts >>$file_write
        echo -e $end >>$file_write
        echo -e " ***** HOSTNAME OF THE SERVER *****\n" >>$file_write
        hostname >>$file_write
        echo -e $end >>$file_write
    }

    function host_os_check2() {
        echo -e "***** PORTS ON LISTENING \n" >>$file_write
        netstat -auntp | grep -i listen >>$file_write
        echo -e $end >>$file_write
    }

    function docker_check() {
        echo -e "***** DOCKER DETAILS ***** \n"  >> $file_write
        echo -e $end >> $file_write
        echo -e "***** DOCKER IMAGES ***** \n" >> $file_write
        docker images --digests >> $file_write
        echo -e $end >> $file_write
        echo -e "***** DOCKER VERSION ***** \n" >> $file_write
        docker --version >> $file_write
        echo -e $end >> $file_write
        echo -e "***** DOCKER COMPOSE VERISON ***** \n" >> $file_write
        docker-compose --version >> $file_write
        echo -e $end >> $file_write
    }

    function podman_check() {
        echo -e "***** PODMAN DETAILS ***** \n"  >> $file_write
        podman ps -a >> $file_write
        echo -e $end >> $file_write
        echo -e "***** PODMAN IMAGES ***** \n" >> $file_write
        podman images --digests >> $file_write
        echo -e $end >> $file_write
        echo -e "***** PODMAN VERSION ***** \n" >> $file_write
        podman --version >> $file_write
        echo -e $end >> $file_write
        echo -e "***** PODMAN COMPOSE VERISON ***** \n" >> $file_write
        podman-compose --version >> $file_write
        echo -e $end >> $file_write
    }

    function micro_ad_logs() {
        path=$(find /DNIF -type f -name "docker-compose.yaml" | grep -v '/DNIF/backup/ad' | grep -v '/DNIF/EB/docker-compose.yaml' | sed 's|/DNIF/||; s|/docker-compose.yaml$||')
        for j in $path; do
            full_path="/DNIF/$j"            
            tar czf "$cwd/service_logs_${dateis}_$j.tar.gz" --absolute-names "$full_path/log/" "$full_path/csltuconfig/" "$full_path/csltudata/" "$full_path/rabbitmq/log" "$full_path/redis/log" 
        done
    }

    function micro_ad_logs_pod() {
        path=$(find /DNIF -type f -name "podman-compose.yaml" | grep -v '/DNIF/backup/ad' | grep -v '/DNIF/EB/podman-compose.yaml' | sed 's|/DNIF/||; s|/podman-compose.yaml$||')
        for j in $path; do
            full_path="/DNIF/$j"            
            tar czf "$cwd/service_logs_${dateis}_$j.tar.gz" --absolute-names "$full_path/log/" "$full_path/csltuconfig/" "$full_path/csltudata/" "$full_path/rabbitmq/log" "$full_path/redis/log" 
        done
    }

    function lc_doc() {
        cd /DNIF/LC/
        compname="LC"
        echo -e "***** DOCKER COMPOSE YAML ***** \n" >> $file_write
        cat docker-compose.yaml >> $file_write
        echo -e $end >> $file_write
        echo -e "*****DOCKER COMPOSE LOGS ***** \n" >> $file_write
        docker-compose logs >> $file_write
        echo -e $end >> $file_write
        echo -e "***** HOST FILE INSIDE THE CONATINER ***** \n" >> $file_write
        docker exec console-v9 cat /etc/hosts >> $file_write            
        echo -e $end >> $file_write
        echo -e "***** SUPERVISORCTL STATUS ***** \n" >> $file_write
        docker exec console-v9 supervisorctl status >> $file_write
        echo -e $end >> $file_write
        echo -e "***** PROXY INSIDE THE CONATINER ***** \n" >> $file_write
        docker exec console-v9 env | grep -i proxy >> $file_write   
        echo -e $end >> $file_write
        echo -e "***** HOSTNAME INSIDE THE CONTAINER ***** \n" >> $file_write
        docker exec console-v9 hostname >> $file_write
        echo -e "***** NGINX STATUS ***** \n" >> $file_write
        docker exec console-v9 /etc/init.d/nginx status >> $file_write             
        echo -e $end >> $file_write
    }

    function co_doc() {
        cd /DNIF/
        compname=$"CO"
        echo -e "***** DOCKER COMPOSE YAML (CORE) ***** \n" >> $file_write
        cat docker-compose.yaml >> $file_write
        echo -e $end >> $file_write
        echo -e "*****DOCKER COMPOSE LOGS (CORE) *****\n" >> $file_write
        docker-compose logs >> $file_write
        echo -e $end >> $file_write
        echo -e '***** HOST FILE INSIDE THE CONATINER (CORE)***** \n' >> $file_write
        docker exec core-v9 cat /etc/hosts >> $file_write
        echo -e $end >> $file_write
        echo -e "***** HOST FILE INSIDE THE CONATINER (MASTER DN )***** \n" >> $file_write
        docker exec datanode-master-v9 cat /etc/hosts >> $file_write
        echo -e $end >> $file_write
        echo -e '***** SUPERVISORCTL STATUS (CORE) *****\n' >> $file_write
        docker exec core-v9 supervisorctl status >> $file_write
        echo -e $end >> $file_write
        echo -e '***** SUPERVISORCTL STATUS (MASTER DN) *****\n' >> $file_write
        docker exec datanode-master-v9 supervisorctl status >> $file_write
        echo -e $end >> $file_write
        echo -e "***** HADOOP NAMENDOE STATUS *****" >> $file_write
        systemctl status hadoop-namenode.service | grep -i active >> $file_write
        echo -e $end	 >> $file_write
        echo -e '***** PROXY INSIDE THE CONATINER (CORE) *****\n' >> $file_write
        docker exec core-v9 env | grep -i proxy >> $file_write
        echo -e $end >> $file_write
        echo -e '***** PROXY INSIDE THE CONATINER (MASTER DN) *****\n' >> $file_write
        docker exec datanode-master-v9 env | grep -i proxy >> $file_write
        echo -e $end >> $file_write
        echo -e '***** HOSTNAME INSIDE THE CONTAINER ***** (CORE)\n' >> $file_write
        docker exec core-v9 hostname >> $file_write
        echo -e $end >> $file_write
        echo -e '***** HOSTNAME INSIDE THE CONTAINER (MASTER DN)*****\n' >> $file_write
        docker exec datanode-master-v9 hostname >> $file_write
        echo -e $end >> $file_write
        co_service_logs
        hdfs_check
    }

    function dn_doc() {
        if [[ -e /DNIF/DL/docker-compose.yaml ]]; then
            cd /DNIF/DL
            compname=$"DN"
            echo -e "***** DOCKER COMPOSE YAML *****\n" >> $file_write
            cat docker-compose.yaml >> $file_write
            echo -e $end >> $file_write
            echo -e "*****DOCKER COMPOSE LOGS *****\n" >> $file_write
            docker-compose logs >> $file_write
            echo -e $end >> $file_write
            echo -e "***** HOST FILE INSIDE THE CONATINER *****\n" >> $file_write
            docker exec datanode-v9 cat /etc/hosts >> $file_write
            echo -e $end >> $file_write
            echo -e "***** SUPERVISORCTL STATUS *****\n" >> $file_write
            docker exec datanode-v9 supervisorctl status >> $file_write
            echo -e $end >> $file_write
            hadoop_spark_servers_status
            echo -e "***** PROXY INSIDE THE CONATINER *****\n" >> $file_write
            docker exec datanode-v9 env | grep -i proxy >> $file_write
            echo -e $end >> $file_write
            echo -e "***** HOSTNAME INSIDE THE CONTAINER *****\n" >> $file_write
            docker exec datanode-v9 hostname >> $file_write
            echo -e $end >> $file_write
            dn_service_logs
        fi
    }

    function pc_doc() {
        cd /DNIF/PICO/
            compname=$"PC"
            echo -e "***** DOCKER COMPOSE YAML (PICO) ***** \n" >> $file_write
            cat docker-compose.yaml >> $file_write
            echo -e $end >> $file_write
            echo -e "***** DOCKER COMPOSE LOGS (PICO) *****\n" >> $file_write
            docker-compose logs >> $file_write
            echo -e $end >> $file_write
            echo -e '***** HOST FILE INSIDE THE CONATINER *****' >> $file_write
            docker exec pico-v9 cat /etc/hosts >> $file_write
            echo -e $end >> $file_write
            echo -e '***** SUPERVISORCTL STATUS *****\n' >> $file_write
            docker exec pico-v9 supervisorctl status >> $file_write
            echo -e $end >> $file_write
            echo -e '***** PROXY INSIDE THE CONATINER *****\n' >> $file_write
            docker exec pico-v9 env | grep -i proxy >> $file_write
            echo -e $end >> $file_write
            echo -e '***** HOSTNAME INSIDE THE CONTAINER *****\n' >> $file_write
            docker exec pico-v9 hostname >> $file_write
            echo -e $end >> $file_write
            echo -e "***** RABBITMQCTL SERVER STATUS  *****" >> $file_write
            docker exec pico-v9 bash -c 'source /etc/profile && /etc/init.d/rabbitmq-server status' >> $file_write
            echo -e $end >> $file_write
            echo -e "***** RABBITMQCTL QUEUES STATUS  *****" >> $file_write
            docker exec pico-v9 bash -c 'source /etc/profile && rabbitmqctl list_queues' >> $file_write
            echo -e $end >> $file_write
            echo -e "***** REDIES SERVER STATUS  *****" >> $file_write
            docker exec pico-v9 bash -c '/etc/init.d/redis-server status' >> $file_write
            echo -e $end >> $file_write
            ip_connectivity
            echo -e $end >> $file_write
            pc_service_logs
    }

    function ad_doc_n() {
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w adapter-v9) == "adapter-v9" ]]; then
                cd /DNIF/AD/
                compname=$"AD"
                echo -e "***** DOCKER COMPOSE YAML (ADAPTER) ***** \n" >> $file_write
                cat docker-compose.yaml >> $file_write
                echo -e $end >> $file_write
                echo -e "*****DOCKER COMPOSE LOGS (ADAPTER) ***** \n" >> $file_write
                docker-compose logs >> $file_write
                echo -e $end >> $file_write
                echo -e '***** HOST FILE INSIDE THE CONATINER ***** \n' >> $file_write
                docker exec adapter-v9 cat /etc/hosts >> $file_write
                echo -e $end >> $file_write
                echo -e '***** SUPERVISORCTL STATUS ***** \n' >> $file_write
                docker exec adapter-v9 supervisorctl status >> $file_write
                echo -e $end >> $file_write
                echo -e '***** PROXY INSIDE THE CONATINER ***** \n' >> $file_write
                docker exec adapter-v9 env | grep -i proxy >> $file_write
                echo -e $end >> $file_write
                echo -e '***** HOSTNAME INSIDE THE CONTAINER *****\n' >> $file_write
                docker exec adapter-v9 hostname >> $file_write
                echo -e $end >> $file_write
                echo -e "***** RABBITMQCTL SERVER STATUS  *****" >> $file_write
                docker exec adapter-v9 bash -c 'source /etc/profile && /etc/init.d/rabbitmq-server status' >> $file_write
                echo -e $end >> $file_write
                echo -e "***** RABBITMQCTL QUEUES STATUS  *****" >> $file_write
                docker exec adapter-v9 bash -c 'source /etc/profile && rabbitmqctl list_queues' >> $file_write
                echo -e $end >> $file_write
                echo -e "***** REDIES SERVER STATUS  *****" >> $file_write
                docker exec adapter-v9 bash -c '/etc/init.d/redis-server status' >> $file_write
                echo -e $end >> $file_write
                ad_service_logs
        fi
    }

    function ad_doc_m() {
        ad_path=$(find /DNIF -type f -name "docker-compose.yaml" | grep -v '/DNIF/backup/ad' | grep -v '/DNIF/EB/docker-compose.yaml' | sed 's/\/docker-compose.yaml$//')
        
        for a in $ad_path; do
            cd "$a" || continue
            #echo -e "$(pwd)"
            #echo -e "$a"
            container_name=$(grep -i "container_name:" docker-compose.yaml | awk '{print $2}')
            #echo -e "$container_name"
            echo -e "***** DOCKER COMPOSE YAML $container_name ***** \n" >> $file_write
            cat docker-compose.yaml >> $file_write
            echo -e $end >> $file_write
            echo -e "***** DOCKER COMPOSE LOGS $container_name ***** \n" >> $file_write
            docker-compose logs >> $file_write
            echo -e $end >> $file_write
            echo -e "***** HOST FILE INSIDE THE CONTAINER $container_name ***** \n" >> $file_write
            docker exec "$container_name" cat /etc/hosts >> $file_write
            echo -e $end >> $file_write
            echo -e "***** PROXY INSIDE THE CONTAINER $container_name ***** \n" >> $file_write
            docker exec "$container_name" env | grep -i proxy >> $file_write
            echo -e $end >> $file_write
            echo -e "***** HOSTNAME INSIDE THE CONTAINER $container_name *****\n" >> $file_write
            docker exec "$container_name" hostname >> $file_write
            echo -e $end >> $file_write
            echo -e "***** SUPERVISORCTL STATUS $container_name ***** \n" >> $file_write
            docker exec "$container_name" supervisorctl status >> $file_write
            echo -e $end >> $file_write
            echo -e "***** REDIS SERVER STATUS $container_name *****" >> $file_write
            docker exec "$container_name" bash -c '/etc/init.d/redis-server status' >> $file_write
            echo -e $end >> $file_write
            ad_service_logs_m
        done
        echo -e "***** RABBITMQCTL QUEUES STATUS  *****" >> $file_write
        docker exec $(docker ps -aqf "name=eventbus-v9") bash -c 'source /etc/profile && rabbitmqctl list_queues' >> $file_write
        echo -e $end >> $file_write
        
        echo -e "***** RABBITMQCTL SERVER STATUS  *****" >> $file_write
        docker exec $(docker ps -aqf "name=eventbus-v9") bash -c 'source /etc/profile && /etc/init.d/rabbitmq-server status' >> $file_write
        echo -e $end >> $file_write
    }
    
    function lc_pod() {
        cd /DNIF/LC/
        compname="LC"
        echo -e "***** podman COMPOSE YAML ***** \n" >> $file_write
        cat podman-compose.yaml >> $file_write
        echo -e $end >> $file_write
        echo -e "*****podman COMPOSE LOGS ***** \n" >> $file_write
        podman-compose logs >> $file_write
        echo -e $end >> $file_write
        echo -e "***** HOST FILE INSIDE THE CONATINER ***** \n" >> $file_write
        podman exec console-v9 cat /etc/hosts >> $file_write            
        echo -e $end >> $file_write
        echo -e "***** SUPERVISORCTL STATUS ***** \n" >> $file_write
        podman exec console-v9 supervisorctl status >> $file_write
        echo -e $end >> $file_write
        echo -e "***** PROXY INSIDE THE CONATINER ***** \n" >> $file_write
        podman exec console-v9 env | grep -i proxy >> $file_write   
        echo -e $end >> $file_write
        echo -e "***** HOSTNAME INSIDE THE CONTAINER ***** \n" >> $file_write
        podman exec console-v9 hostname >> $file_write
        echo -e "***** NGINX STATUS ***** \n" >> $file_write
        podman exec console-v9 /etc/init.d/nginx status >> $file_write            
        echo -e $end >> $file_write
    }
    
    function co_pod() {
        cd /DNIF/
        compname=$"CO"
        echo -e "***** podman COMPOSE YAML (CORE) ***** \n" >> $file_write
        cat podman-compose.yaml >> $file_write
        echo -e $end >> $file_write
        echo -e "*****podman COMPOSE LOGS (CORE) *****\n" >> $file_write
        podman-compose logs >> $file_write
        echo -e $end >> $file_write
        echo -e '***** HOST FILE INSIDE THE CONATINER (CORE)***** \n' >> $file_write
        podman exec core-v9 cat /etc/hosts >> $file_write
        echo -e $end >> $file_write
        echo -e "***** HOST FILE INSIDE THE CONATINER (MASTER DN )***** \n" >> $file_write
        podman exec datanode-v9 cat /etc/hosts >> $file_write
        echo -e $end >> $file_write
        echo -e '***** SUPERVISORCTL STATUS (CORE) *****\n' >> $file_write
        podman exec core-v9 supervisorctl status >> $file_write
        echo -e $end >> $file_write
        echo -e '***** SUPERVISORCTL STATUS (MASTER DN) *****\n' >> $file_write
        podman exec datanode-v9 supervisorctl status >> $file_write
        echo -e $end >> $file_write
        echo -e "***** HADOOP NAMENDOE STATUS *****" >> $file_write
        systemctl status hadoop-namenode.service | grep -i active >> $file_write
        echo -e $end	 >> $file_write
        echo -e '***** PROXY INSIDE THE CONATINER (CORE) *****\n' >> $file_write
        podman exec core-v9 env | grep -i proxy >> $file_write
        echo -e $end >> $file_write
        echo -e '***** PROXY INSIDE THE CONATINER (MASTER DN) *****\n' >> $file_write
        podman exec datanode-v9 env | grep -i proxy >> $file_write
        echo -e $end >> $file_write
        echo -e '***** HOSTNAME INSIDE THE CONTAINER ***** (CORE)\n' >> $file_write
        podman exec core-v9 hostname >> $file_write
        echo -e $end >> $file_write
        echo -e '***** HOSTNAME INSIDE THE CONTAINER (MASTER DN)*****\n' >> $file_write
        podman exec datanode-v9 hostname >> $file_write
        echo -e $end >> $file_write
        co_service_logs
        hdfs_check
    }

    function dn_pod() {
        if [[ -e /DNIF/DL/podman-compose.yaml ]]; then
            cd /DNIF/DL
            compname=$"DN"
            echo -e "***** podman COMPOSE YAML *****\n" >> $file_write
            cat podman-compose.yaml >> $file_write
            echo -e $end >> $file_write
            echo -e "*****podman COMPOSE LOGS *****\n" >> $file_write
            podman-compose logs >> $file_write
            echo -e $end >> $file_write
            echo -e "***** HOST FILE INSIDE THE CONATINER *****\n" >> $file_write
            podman exec datanode-v9 cat /etc/hosts >> $file_write
            echo -e $end >> $file_write
            echo -e "***** SUPERVISORCTL STATUS *****\n" >> $file_write
            podman exec datanode-v9 supervisorctl status >> $file_write
            echo -e $end >> $file_write
            hadoop_spark_servers_status
            echo -e "***** PROXY INSIDE THE CONATINER *****\n" >> $file_write
            podman exec datanode-v9 env | grep -i proxy >> $file_write
            echo -e $end >> $file_write
            echo -e "***** HOSTNAME INSIDE THE CONTAINER *****\n" >> $file_write
            podman exec datanode-v9 hostname >> $file_write
            echo -e $end >> $file_write
            dn_service_logs
        fi
    }

    function pc_pod() {
        cd /DNIF/PICO/
            compname=$"PC"
            echo -e "***** podman COMPOSE YAML (PICO) ***** \n" >> $file_write
            cat podman-compose.yaml >> $file_write
            echo -e $end >> $file_write
            echo -e "***** podman COMPOSE LOGS (PICO) *****\n" >> $file_write
            podman-compose logs >> $file_write
            echo -e $end >> $file_write
            echo -e '***** HOST FILE INSIDE THE CONATINER *****' >> $file_write
            podman exec pico-v9 cat /etc/hosts >> $file_write
            echo -e $end >> $file_write
            echo -e '***** SUPERVISORCTL STATUS *****\n' >> $file_write
            podman exec pico-v9 supervisorctl status >> $file_write
            echo -e $end >> $file_write
            echo -e '***** PROXY INSIDE THE CONATINER *****\n' >> $file_write
            podman exec pico-v9 env | grep -i proxy >> $file_write
            echo -e $end >> $file_write
            echo -e '***** HOSTNAME INSIDE THE CONTAINER *****\n' >> $file_write
            podman exec pico-v9 hostname >> $file_write
            echo -e $end >> $file_write
            echo -e "***** RABBITMQCTL SERVER STATUS  *****" >> $file_write
            podman exec pico-v9 bash -c 'source /etc/profile && /etc/init.d/rabbitmq-server status' >> $file_write
            echo -e $end >> $file_write
            echo -e "***** RABBITMQCTL QUEUES STATUS  *****" >> $file_write
            podman exec pico-v9 bash -c 'source /etc/profile && rabbitmqctl list_queues' >> $file_write
            echo -e $end >> $file_write
            echo -e "***** REDIES SERVER STATUS  *****" >> $file_write
            podman exec pico-v9 bash -c '/etc/init.d/redis-server status' >> $file_write
            echo -e $end >> $file_write
            ip_connectivity
            echo -e $end >> $file_write
            pc_service_logs
    }

    function ad_pod_n() {
        if [[ $(podman ps -a --format '{{.Names}}' | grep -w adapter-v9) == "adapter-v9" ]]; then
                cd /DNIF/AD/
                compname=$"AD"
                echo -e "***** podman COMPOSE YAML (ADAPTER) ***** \n" >> $file_write
                cat podman-compose.yaml >> $file_write
                echo -e $end >> $file_write
                echo -e "*****podman COMPOSE LOGS (ADAPTER) ***** \n" >> $file_write
                podman-compose logs >> $file_write
                echo -e $end >> $file_write
                echo -e '***** HOST FILE INSIDE THE CONATINER ***** \n' >> $file_write
                podman exec adapter-v9 cat /etc/hosts >> $file_write
                echo -e $end >> $file_write
                echo -e '***** SUPERVISORCTL STATUS ***** \n' >> $file_write
                podman exec adapter-v9 supervisorctl status >> $file_write
                echo -e $end >> $file_write
                echo -e '***** PROXY INSIDE THE CONATINER ***** \n' >> $file_write
                podman exec adapter-v9 env | grep -i proxy >> $file_write
                echo -e $end >> $file_write
                echo -e '***** HOSTNAME INSIDE THE CONTAINER *****\n' >> $file_write
                podman exec adapter-v9 hostname >> $file_write
                echo -e $end >> $file_write
                echo -e "***** RABBITMQCTL SERVER STATUS  *****" >> $file_write
                podman exec adapter-v9 bash -c 'source /etc/profile && /etc/init.d/rabbitmq-server status' >> $file_write
                echo -e $end >> $file_write
                echo -e "***** RABBITMQCTL QUEUES STATUS  *****" >> $file_write
                podman exec adapter-v9 bash -c 'source /etc/profile && rabbitmqctl list_queues' >> $file_write
                echo -e $end >> $file_write
                echo -e "***** REDIES SERVER STATUS  *****" >> $file_write
                podman exec adapter-v9 bash -c '/etc/init.d/redis-server status' >> $file_write
                echo -e $end >> $file_write
                ad_service_logs
        fi
    }

    function ad_pod_m() {
        ad_path=$(find /DNIF -type f -name "podman-compose.yaml" | grep -v '/DNIF/backup/ad' | grep -v '/DNIF/EB/podman-compose.yaml' | sed 's/\/podman-compose.yaml$//')
        for a in $ad_path; do
            cd "$a" || continue
            #echo -e "$(pwd)"
            #echo -e "$a"
            container_name=$(grep -i "container_name:" podman-compose.yaml | awk '{print $2}')
            #echo -e "$container_name"
            echo -e "***** podman COMPOSE YAML $container_name ***** \n" >> $file_write
            cat podman-compose.yaml >> $file_write
            echo -e $end >> $file_write
            echo -e "***** podman COMPOSE LOGS $container_name ***** \n" >> $file_write
            podman-compose logs >> $file_write
            echo -e $end >> $file_write
            echo -e "***** HOST FILE INSIDE THE CONTAINER $container_name ***** \n" >> $file_write
            podman exec "$container_name" cat /etc/hosts >> $file_write
            echo -e $end >> $file_write
            echo -e "***** PROXY INSIDE THE CONTAINER $container_name ***** \n" >> $file_write
            podman exec "$container_name" env | grep -i proxy >> $file_write
            echo -e $end >> $file_write
            echo -e "***** HOSTNAME INSIDE THE CONTAINER $container_name *****\n" >> $file_write
            podman exec "$container_name" hostname >> $file_write
            echo -e $end >> $file_write
            echo -e "***** SUPERVISORCTL STATUS $container_name ***** \n" >> $file_write
            podman exec "$container_name" supervisorctl status >> $file_write
            echo -e $end >> $file_write
            echo -e "***** REDIS SERVER STATUS $container_name *****" >> $file_write
            podman exec "$container_name" bash -c '/etc/init.d/redis-server status' >> $file_write
            echo -e $end >> $file_write
            ad_service_logs_m
        done
        echo -e "***** RABBITMQCTL QUEUES STATUS  *****" >> $file_write
        podman exec $(podman ps -aqf "name=eventbus-v9") bash -c 'source /etc/profile && rabbitmqctl list_queues' >> $file_write
        echo -e $end >> $file_write
        
        echo -e "***** RABBITMQCTL SERVER STATUS  *****" >> $file_write
        podman exec $(podman ps -aqf "name=eventbus-v9") bash -c 'source /etc/profile && /etc/init.d/rabbitmq-server status' >> $file_write
        echo -e $end >> $file_write
    }
    function hdfs_check() {
        uname=$(cat /DNIF/DL/csltuconfig/username)
        export HADOOP_USER_NAME=$uname
        cd /opt/hadoop/bin/
        ./hdfs dfsadmin -report >> $cwd/dfsadmin_$dateis.out
        ./hdfs fsck / >> $cwd/fsck_$dateis.out
    }

    file_remove
    host_os_check
    if [[ $os == "ubuntu" ]]; then
        echo -ne '##                    (10%)\r'
        docker_check
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w console-v9) == "console-v9" ]]; then
            echo -ne '######                    (30%)\r'
            lc_doc
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/LC/log/ /DNIF/LC/config/
            echo -ne '##########                    (50%)\r'
        fi
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w core-v9) == "core-v9" ]]; then
            echo -ne '######                    (30%)\r'
            co_doc
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/DL/log/ /DNIF/DL/csltuconfig/  /DNIF/CO/log/ /DNIF/CO/csltuconfig/ /opt/hadoop/logs/  /DNIF/CO/core/notable* 
            echo -ne '##########                    (50%)\r'
        fi
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w datanode-v9) == "datanode-v9" ]]; then
            dn_doc
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/DL/correlation_server/logs/ /DNIF/DL/report_server/logs/ /DNIF/DL/query_server/logs/ /DNIF/DL/log/ /DNIF/DL/csltuconfig/ /opt/spark/logs/ /opt/hadoop/logs/ 
        fi
        if [[ $(docker ps -a --format "{{.Names}}" | grep -i "eventbus-v9") == "eventbus-v9" ]]; then
            compname=$"AD"
            echo -ne '######                    (30%)\r'
            ad_doc_m
            echo -ne '########                    (40%)\r'
            micro_ad_logs
            echo -ne '##########                    (50%)\r'
        else
            if [[ $(docker ps -a --format '{{.Names}}' | grep -w adapter-v9) == "adapter-v9" ]]; then
                compname=$"AD"
                echo -ne '######                    (30%)\r'
                ad_doc_n
                echo -ne '########                    (40%)\r'
                tar -czf $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/AD/log/ /DNIF/AD/csltuconfig/ /DNIF/AD/csltudata/ /DNIF/AD/rabbitmq/log /DNIF/AD/redis/log
                echo -ne '##########                    (50%)\r'
            fi
        fi
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w pico-v9) == "pico-v9" ]]; then
            echo -ne '######                    (30%)\r'
            pc_doc
            ip_connectivity
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/PICO/log/ /DNIF/PICO/csltuconfig/
            echo -ne '##########                    (50%)\r'
        fi
        echo -ne '###########                    (60%)\r'
        echo -e "***** FIREWALL STATUS ***** \n" >> $file_write
        ufw status >> $file_write
        echo -e $end >> $file_write
        echo -ne '############                    (80%)\r'
        tar fcz $cwd/OS_logs_$dateis.tar.gz --absolute-names /var/log/syslog* /var/log/kern.log* /var/log/dmesg*
    fi
    if [[ $os == "rhel" ]]; then
        echo -ne '##                    (10%)\r'
        podman_check
        if [[ $(podman ps -a --format '{{.Names}}' | grep -w console-v9) == "console-v9" ]]; then
            echo -ne '######                    (30%)\r'
            lc_pod
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/LC/log/ /DNIF/LC/config/
            echo -ne '##########                    (50%)\r'
        fi
        if [[ $(podman ps -a --format '{{.Names}}' | grep -w datanode-v9) == "datanode-v9" ]]; then
            echo -ne '######                    (30%)\r'
            dn_pod
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/DL/correlation_server/logs/ /DNIF/DL/report_server/logs/ /DNIF/DL/query_server/logs/ /DNIF/DL/log/ /DNIF/DL/csltuconfig/ /opt/spark/logs/ /opt/hadoop/logs/ 
            echo -ne '##########                    (50%)\r'
        fi
        if [[ $(podman ps -a --format '{{.Names}}' | grep -w core-v9) == "core-v9" ]]; then
            echo -ne '######                    (30%)\r'
            co_pod
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/DL/log/ /DNIF/DL/csltuconfig/  /DNIF/CO/log/ /DNIF/CO/csltuconfig/ /opt/hadoop/logs/  /DNIF/CO/core/notable* 
            echo -ne '##########                    (50%)\r'
        fi
        if [[ $(podman ps -a --format "{{.Names}}" | grep -i "eventbus-v9") == "eventbus-v9" ]]; then
            compname=$"AD"
            echo -ne '######                    (30%)\r'
            ad_pod_m
            echo -ne '########                    (40%)\r'
            micro_ad_logs_pod
            echo -ne '##########                    (50%)\r'
        else
            if [[ $(podman ps -a --format "{{.Names}}" | grep -i "eventbus-v9") == "adapter-v9" ]]; then
                compname=$"AD"
                echo -ne '######                    (30%)\r'
                ad_pod_n
                echo -ne '########                    (40%)\r'
                tar -czf $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/AD/log/ /DNIF/AD/csltuconfig/ /DNIF/AD/csltudata/ /DNIF/AD/rabbitmq/log /DNIF/AD/redis/log
                echo -ne '##########                    (50%)\r'
            fi
        fi
        if [[ $(podman ps -a --format '{{.Names}}' | grep -w pico-v9) == "pico-v9" ]]; then
            echo -ne '######                    (30%)\r'
            pc_pod
            ip_connectivity
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/PICO/log/ /DNIF/PICO/csltuconfig/
            echo -ne '##########                    (50%)\r'
        fi
        echo -ne '###########                    (60%)\r'
        echo -e " ***** FIREWALL STATUS ***** \n"  >> $file_write
        systemctl staus firewalld.service >> $file_write
        echo -e $end >> $file_write
        echo -ne '############                    (80%)\r'
        tar fcz $cwd/OS_logs_$dateis.tar.gz --absolute-names /var/log/syslog* /var/log/kern.log* /var/log/dmes* /var/log/mes*
    fi
    if [[ $os == "centos" ]]; then
        echo -ne '##                    (10%)\r'
        docker_check
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w console-v9) == "console-v9" ]]; then
            echo -ne '######                    (30%)\r'
            lc_doc
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/LC/log/ /DNIF/LC/config/
            echo -ne '##########                    (50%)\r'
        fi
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w core-v9) == "core-v9" ]]; then
            echo -ne '######                    (30%)\r'
            co_doc
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/DL/log/ /DNIF/DL/csltuconfig/  /DNIF/CO/log/ /DNIF/CO/csltuconfig/ /opt/hadoop/logs/  /DNIF/CO/core/notable* 
            echo -ne '##########                    (50%)\r'
        fi
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w datanode-v9) == "datanode-v9" ]]; then
            echo -ne '######                    (30%)\r'
            dn_doc
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/DL/correlation_server/logs/ /DNIF/DL/report_server/logs/ /DNIF/DL/query_server/logs/ /DNIF/DL/log/ /DNIF/DL/csltuconfig/ /opt/spark/logs/ /opt/hadoop/logs/ 
            echo -ne '##########                    (50%)\r'
        fi
        if [[ $(docker ps -a --format "{{.Names}}" | grep -i "eventbus-v9") == "eventbus-v9" ]]; then
            compname=$"AD"
            echo -ne '######                    (30%)\r'
            ad_doc_m
            echo -ne '########                    (40%)\r'
            micro_ad_logs
            echo -ne '##########                    (50%)\r'
        else
            if [[ $(docker ps -a --format '{{.Names}}' | grep -w adapter-v9) == "adapter-v9" ]]; then
                compname=$"AD"
                echo -ne '######                    (30%)\r'
                ad_doc_n
                echo -ne '########                    (40%)\r'
                tar -czf $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/AD/log/ /DNIF/AD/csltuconfig/ /DNIF/AD/csltudata/ /DNIF/AD/rabbitmq/log /DNIF/AD/redis/log
                echo -ne '##########                    (50%)\r'
            fi
        fi
        if [[ $(docker ps -a --format '{{.Names}}' | grep -w pico-v9) == "pico-v9" ]]; then
            echo -ne '######                    (30%)\r'
            pc_doc
            ip_connectivity
            echo -ne '########                    (40%)\r'
            tar fcz $cwd/service_logs_$dateis.tar.gz --absolute-names /DNIF/PICO/log/ /DNIF/PICO/csltuconfig/
            echo -ne '##########                    (50%)\r'
        fi
        echo -ne '###########                    (60%)\r'
        echo -e "***** FIREWALL STATUS ***** \n" >> $file_write
        ufw status >> $file_write
        echo -e $end >> $file_write
        echo -ne '############                    (80%)\r'
        tar $cwd/fcz OS_logs_$dateis.tar.gz --absolute-names /var/log/syslog* /var/log/kern.log* /var/log/dmesg*
    fi
    echo -ne '##############                    (85%)\r'
    host_os_check2
    cd $cwd
    HISTFILE=~/.bash_history
    set -o history
    history >> history_$dateis.log
    top -c -b -n 5 > top_$dateis.log
    ps aux --sort -pcpu >> ps_pcpu_$dateis.log
    ps aux --sort -rss >> ps_rss_$dateis.log
    echo -ne '##############                    (90%)\r'
    tar -czf System_Report_"$compname"_"$dateis".tar.gz --absolute-names Setup_Report_"$dateis".log dfsadmin_$dateis.out fsck_$dateis.out OS_logs_"$dateis".tar.gz history_"$dateis".log top_"$dateis".log ps_pcpu_"$dateis".log ps_rss_"$dateis".log service_logs_"$dateis"*.tar.gz
    file_remove
    if [[ -e $cwd/Setup_Report_$dateis.log ]]; then
        rm -f "$cwd/Setup_Report_$dateis.log"
    fi
    echo -ne '#################                    (100%)\n'
fi