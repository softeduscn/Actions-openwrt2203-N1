#!/bin/bash

if [ "$(ps | grep -v grep | grep sysmonitor.sh | wc -l)" -gt 2 ]; then
	exit 1
fi

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

ping_url() {
	local url=$1
	for i in $( seq 1 3 ); do
		status=$(ping -c 1 -W 1 $url | grep -o 'time=[0-9]*.*' | awk -F '=' '{print$2}'|cut -d ' ' -f 1)
		[ "$status" == "" ] && status=0
		[ "$status" != 0 ] && break
	done
	echo $status
}

cat /etc/shadow | grep root:::0:99999:7::: > /dev/null
if [ $? -eq 0 ]; then
	sed -i 's/root.*$/root:$1$TADtMues$II9qrw8S7H3hYtJASm0tw.:19059:0:99999:7:::/g' /etc/shadow
fi

m=$(cat /etc/config/firewall|grep "config zone"|wc -l)
let "m=m-1"
for ((i=$m;i>=0;i--))
do
	[ $(uci get firewall.@zone[$i].name) == "wan" ] && uci del firewall.@zone[$i]	
done
m=$(cat /etc/config/firewall|grep "config forwarding"|wc -l)
let "m=m-1"
for ((i=$m;i>=0;i--))
do
	uci del firewall.@forwarding[$i]
done
uci commit firewall
cat >> /etc/config/firewall <<EOF
config forwarding
	option src 'wghome'
	option dest 'lan'
EOF
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

	[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0

	num=0
	while [ $num -le 10 ]; do
		sleep $sleep_unit
		[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0
		let num=num+sleep_unit
		if [ -f "/tmp/sysmonitor" ]; then
			rm /tmp/sysmonitor
			num=50
		fi
	done
done


