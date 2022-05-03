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

while [ "1" == "1" ]; do #死循环
	if [ $(uci get network.lan.ipaddr) == '192.168.1.111' ]; then
		status=$(ping_url "192.168.1.110")
		if [ "$status" == 0 ]; then
			uci set network.lan.ipaddr='192.168.1.110'
			uci commit network
			ifup lan &
		fi
	fi
	if [ $(uci get sysmonitor.sysmonitor.ddnsmonitor) == 1 ]; then
		if [ -f "/etc/init.d/ddns" ]; then
			[ $(ps -w|grep ddns|grep -v grep|wc -l) == 0 ] && /etc/init.d/ddns restart &
		fi
	fi
	[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0

	num=0
	while [ $num -le 30 ]; do
		sleep $sleep_unit
		[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0
		let num=num+sleep_unit
		if [ $num -ge 25 ]; then
			[ $fw == 0 ] && /etc/init.d/firewall restart 2>/dev/null
			fw=1			
		fi
	done
done

