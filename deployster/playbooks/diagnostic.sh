#!/bin/bash

# переменные
NODES=(hacnode1 hacnode2 hacnode3)
USER=root

#------------------------------------------------------------
# проверяем время
#------------------------------------------------------------
function check_time
{
    local list=("${!1}")
    local server=${2}
    for node in ${list[@]}
    do
        ssh $USER@$node ntpdate -q $server
    done
}
#------------------------------------------------------------
# сихронизировать время
#------------------------------------------------------------
function sync_time
{
    local list=("${!1}")
    local server=${2}
    for node in ${list[@]}
    do
        ssh $USER@$node ntpdate $server
    done
}
#------------------------------------------------------------
# очистить логи
#------------------------------------------------------------
function cleanup_logs
{
    local list_of_services=(corosync glusterfs-common apache2 hac-control libvirtd libvirtd.qemu fly-dm rsyslog)
    local list_of_nodes=("${!1}")

    for service in ${list_of_services[@]}
    do
        for node in ${list_of_nodes[@]}
        do
            ssh $USER@$node logrotate -f /etc/logrotate.d/${service}
        done
    done

    for node in ${list_of_nodes[@]}
    do
        ssh $USER@$node "test -f /var/log/faillog && rm -f /var/log/faillog"
        ssh $USER@$node "test -f /var/log/ald/aldcd.log && echo "" > /var/log/ald/aldcd.log"
        ssh $USER@$node "test -f /var/log/ald/aldd.log && echo "" >  /var/log/ald/aldd.log"
        ssh $USER@$node "test -f /var/log/kerberos/kdc.log && echo "" > /var/log/kerberos/kdc.log"
        ssh $USER@$node "test -f /var/log/kerberos/kadmin_server.log && echo "" > /var/log/kerberos/kadmin_server.log"
    done
}
#------------------------------------------------------------
# получить логи
#------------------------------------------------------------
function get_logs
{
    local list_of_logs=(
        ald/aldcd.log
        ald/aldd.log
        corosync/corosync.log
        apache2/error.log
        apache2/hac-control-error.log
        apache2/hac-control-access.log
        glusterfs/bricks/srv-vol.log
        glusterfs/etc-glusterfs-glusterd.vol.log
        glusterfs/glustershd.log
        glusterfs/nfs.log
        glusterfs/var-glusterfs.log
        glusterfs/cli.log
        syslog
        fly-dm.log
        kerberos/kadmin_server.log
        kerberos/kdc.log
        libvirt/libvirtd.log
      )

    local list_of_nodes=("${!1}")
    local path=${2}

    if ! [ -d $path ]; then
        echo "Указан не существующий каталог ${path}"
        exit 1
    fi

    cd $path

    for node in ${list_of_nodes[@]}
    do
        if [ -d $node ]; then
            rm -rf $node
        fi

        mkdir $node

        for log in ${list_of_logs[@]}
        do
            ssh $USER@$node test -f /var/log/${log} && scp $USER@$node:/var/log/${log} ./${node}/ || echo "$(tput setaf 3)Файл ${log} не найден на ${node}$(tput sgr 0)"
        done
    done

    for node in ${list_of_nodes[@]}
    do
        ssh $USER@$node test -d /var/log/libvirt/qemu && scp -r $USER@$node:/var/log/libvirt/qemu ./vm_logs_${node}
    done
}
#------------------------------------------------------------
# получить cib
#------------------------------------------------------------
function get_cib
{
    local section_name=${2}
    local list=("${!1}")

    if [[ ! ($section_name == "all" || $section_name == "configuration" || $section_name == "status") ]]; then
        echo " У данной команды допустимы следующие опции: all, configuration или status"
        exit 1
    fi

    for node in ${list[@]}
    do
        ssh $USER@$node cibadmin --query --scope $section_name
        if [ $? == 0 ] ; then
            break
        fi
    done
}
#------------------------------------------------------------
# получить статус ресурсов КВГ
#------------------------------------------------------------
function get_resources_status
{
    local list=("${!1}")

    for node in ${list[@]}
    do
        ssh $USER@$node crm_mon -1
        if [ $? == 0 ] ; then
            break
        fi
    done
}
#------------------------------------------------------------
# получить cведения о использовании скрипта
#------------------------------------------------------------
usage()
{
cat << EOF
использование: $0 опции

Скрипт для диагностики и сбора логов ПК КВГ
Все права принадлежат ОАО «Северное ПКБ»

Опции:
   -h      Показать список опции
   -t      Проверить время на узлах (необходимо указывать hostname или IP-адрес)
   -s      Синхронизировать время на узлах (необходимо указывать hostname или IP-адрес)
   -l      Собрать логи с узлов
   -c      Очистить логи (используется принудительный вызов logrotate)
   -r      Получить CIB (необходимо указывать опцию: all, configuration, status)
   -m      Запросить текущий статус ресурсов кластера
EOF
}

#------------------------------------------------------------
# обработка параметров
#------------------------------------------------------------

if [ -z "$NODES" ]; then
    echo "Заполните переменную NODES в данном файле, внесите IP\hostname всех узлов КВГ"
    exit 1
fi

while getopts “ht:l:r:s:cm” OPTION
do
     case $OPTION in
         h)
             usage
             ;;
         t)
             ntp_server=${OPTARG}
             check_time NODES[@] $ntp_server
             ;;
         s)
             ntp_server=${OPTARG}
             sync_time NODES[@] $ntp_server
             ;;
         l)
             path=${OPTARG}
             get_logs NODES[@] $path
             ;;
         r)
             section=${OPTARG}
             get_cib NODES[@] $section
             ;;
         c)
	     cleanup_logs NODES[@]
             ;;
         m)
             get_resources_status NODES[@]
             ;;
         ?)
             usage
             exit 1
             ;;
     esac
done

exit 0
