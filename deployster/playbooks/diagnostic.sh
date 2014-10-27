#!/bin/sh

# переменные
NODES=(hacnode1 hacnode2 hacnode3)
OUTPUT_PATH=
NTP_SERVER=
USER=root

#------------------------------------------------------------
# проверяем время
#------------------------------------------------------------
function check_time 
{
    local list=("${!1}")
    for node in ${list[@]}
    do
        ssh $USER@$node date
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
    local list_of_services=(corosync glusterfs-common apache2 hac-control libvirtd libvirt.qemu)
    local list_of_nodes=("${!1}")
    for service in ${list_of_services[@]}
    do
        for node in ${list_of_nodes[@]}
        do
            ssh $USER@$node logrotate -f /etc/logrotate.d/$service
        done
    done
}
#------------------------------------------------------------
# получить логи
#------------------------------------------------------------
function get_logs
{
    local list_of_services=(corosync glusterfs-common apache2 hac-control libvirtd libvirt.qemu)
    local list_of_nodes=("${!1}")
    for service in ${list_of_services[@]}
    do
        for node in ${list_of_nodes[@]}
        do
            ssh $USER@$node logrotate -f logrotate -f /etc/logrotate.d/$service
        done
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
   -t      Запросить время с узлов
   -s      Синхронизировать время на узлах (необходимо указывать hostname или IP-адрес)
   -l      Собрать логи с узлов
   -c      Очистить логи (используется принудительный вызов logrotate)
   -r      Получить CIB (необходимо указывать опцию: all, configuration, status)
EOF
}

#------------------------------------------------------------
# обратотка параметров
#------------------------------------------------------------

if [ -z "$NODES" ]; then
    echo "Заполните переменную NODES в данном файле, внесите IP\hostname всех узлов КВГ"
    exit 1
fi    

while getopts “htl:сr:s:” OPTION
do
     case $OPTION in
         h)
             usage
             ;;
         t)
             check_time NODES[@]
             ;;
         s)
             NTP_SERVER=${OPTARG}
             sync_time NODES[@] $NTP_SERVER
             ;;
         l)
             echo "l"
             ;;
         r)
             section=${OPTARG}
             get_cib NODES[@] $section
             ;;
         с)
	     cleanup_logs NODES[@]
             ;;
         ?)
             usage
             exit 1
             ;;
     esac
done
exit 0

################################################################################
################################################################################
# commands
#if [ -z "`pidof aldd`" ]; then
# echo "Skip, aldd not running" 2>&1 | logger -t 'cron_ald_backup'
# exit 0 
#fi
#sudo rm $PATH_ALD/ald-base.tar.gz &> /dev/null
#sudo rm $PATH_ALD/ald-keys.tar.gz &> /dev/null
#if ! [ -d /var/glusterfs/ald_bck/ ]; then
#   sudo mkdir /var/glusterfs/ald_bck
#fi
##if [ $? != 0 ] ; then
##   echo "каталог под временное хранение ald backup не создан"
#   exit 1
#fi
#sudo ald-init backup &> /dev/null
#if [ $? != 0 ] ; then
#   echo "ald backup не создан, ошибка при выполнении команды ald-init backup"
#   exit 1
#fi
#sudo cp $PATH_ALD/ald-base.tar.gz $PATH_TMP
#sudo cp $PATH_ALD/ald-keys.tar.gz $PATH_TMP
#sudo chmod 777 -R $PATH_TMP
#scp $PATH_TMP/ald-base.tar.gz $USER@$IP_DST:/root/ald-base_${cur_date}.tar.gz
#result_base=$?
#scp $PATH_TMP/ald-keys.tar.gz $USER@$IP_DST:/root/ald-keys_${cur_date}.tar.gz
#result_keys=$?
#if [[ $result_base = 0 && $result_keys = 0 ]] ; then
#   sudo rm -rf $PATH_TMP/*.* &> /dev/null
#   exit 0
#else
#   sudo rm -rf $PATH_TMP/*.* &> /dev/null
#   echo "ошибка при копировании архивов с базой данных или ключами ald"
#   exit 1
#fi
