#!/bin/sh

if [ "$(ps -w | grep -v grep | grep sysmonitor.sh | wc -l)" -gt 2 ]; then
	exit 1
fi

sleep_unit=1
NAME=sysmonitor
APP_PATH=/usr/share/$NAME
fw=0

uci del_list network.lan.dns='192.168.1.1'
uci add_list network.lan.dns='192.168.1.1'
uci commit network

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

ping_url() {
	local url=$1
	for i in $( seq 1 3 ); do
		status=$(ping -c 1 -W 1 $url | grep -o 'time=[0-9]*.*' | awk -F '=' '{print$2}'|cut -d ' ' -f 1)
		[ "$status" == "" ] && status=0
		[ "$status" != 0 ] && break
	done
	echo $status
}

ipold='888'
while [ "1" == "1" ]; do #死循环
	ipv6=$(ip -o -6 addr list br-lan | cut -d ' ' -f7 | cut -d'/' -f1 |head -n1)
	[ ! "$ipold == $ipv6" ] && {
		ipold=$ipv6
		/usr/share/sysmonitor/sysapp.sh getip6
	}

	[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0

	num=0
	while [ $num -le 30 ]; do
		sleep $sleep_unit
		[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0
		let num=num+sleep_unit
		if [ -f "/tmp/sysmonitor" ]; then
			rm /tmp/sysmonitor
			num=50
		fi
#		if [ $num -ge 25 ]; then
#			[ $fw == 0 ] && /etc/init.d/firewall restart 2>/dev/null
#			fw=1			
#		fi
	done
done

