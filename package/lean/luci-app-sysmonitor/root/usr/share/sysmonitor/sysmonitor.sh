#!/bin/bash

[ "$(ps | grep sysmonitor.sh | grep -v grep | wc -l)" -gt 2 ] && exit

sleep_unit=1
NAME=sysmonitor
APP_PATH=/usr/share/$NAME

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

m=$(cat /etc/config/firewall|grep "config rule"|wc -l)
let "m=m-1"
for ((i=$m;i>=0;i--))
do
	[ "$(uci get firewall.@rule[$i].name)" == "Allow-IPSec-ESP" ] && uci del firewall.@rule[$i]
	[ "$(uci get firewall.@rule[$i].name)" == "Allow-ISAKMP" ] && uci del firewall.@rule[$i]
	[ "$(uci get firewall.@rule[$i].name)" == "Support-UDP-Traceroute" ] && uci del firewall.@rule[$i]
done

m=$(cat /etc/config/firewall|grep "config forwarding"|wc -l)
let "m=m-1"
for ((i=$m;i>=0;i--))
do
	[ "$(uci get firewall.@forwarding[$i].src)" == "lan" ] && uci del firewall.@forwarding[$i]
done
uci commit firewall
/etc/init.d/firewall restart >/dev/null 2>&1 &

path=$(ls /mnt|grep mmc|grep 4)
[ -f "/mnt/$path/sha256sums" ] && rm /mnt/$path/sha256sums
sysctl -w net.ipv4.tcp_congestion_control=bbr

ip=$(uci_get_by_name $NAME sysmonitor gateway 0)
uci set network.lan.gateway=$ip
uci commit network
ifup lan

gateway=$(uci get network.lan.gateway)
d=$(date "+%Y-%m-%d %H:%M:%S")
echo $d": Sysmonitor up now." >> /var/log/sysmonitor.log
echo $d": gateway="$gateway >> /var/log/sysmonitor.log

while [ "1" == "1" ]; do #死循环
	ipv6=$(ip -o -6 addr list br-lan | cut -d ' ' -f7)
	cat /www/ip6.html | grep $(echo $ipv6 | cut -d'/' -f1 |head -n1) > /dev/null
	[  $? -ne 0 ] && {
		d=$(date "+%Y-%m-%d %H:%M:%S")
		echo $d": ip6: "$ipv6 >> /var/log/sysmonitor.log
		echo $ipv6 | cut -d'/' -f1 |head -n1 > /www/ip6.html
	}

	[ "$(ps |grep lighttpd|grep -v grep|wc -l)" == 0 ] && /etc/init.d/lighttpd start
	num=0
	check_time=$(uci_get_by_name $NAME sysmonitor time 10)
	[ "$check_time" -le 3 ] && check_time=3
	while [ $num -le $check_time ]; do
		sleep $sleep_unit
		[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0
		let num=num+sleep_unit
		if [ -f "/tmp/sysmonitor" ]; then
			rm /tmp/sysmonitor
			num=50
		fi
	done
done


