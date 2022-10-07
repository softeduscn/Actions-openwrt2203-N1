#!/bin/bash

NAME=sysmonitor
APP_PATH=/usr/share/$NAME
SYSLOG='/var/log/sysmonitor.log'

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$SYSLOG
	number=$(cat $SYSLOG|wc -l)
	[ $number -gt 25 ] && sed -i '1,10d' $SYSLOG
}

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_get_by_type() {
	local ret=$(uci get $1.@$2[0].$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

uci_set_by_type() {
	uci set $1.@$2[0].$3=$4 2>/dev/null
	uci commit $1
}

agh() {
file1="/etc/AdGuardHome.yaml"
if [ -f $file1 ]; then
	status='Stopped'
	[ $(ps -w|grep -v grep|grep AdGuardHome|wc -l) -gt 0 ] && status='Running'
	num1=$(sed -n '/upstream_dns:/=' $file1)
	let num1=num1+1
	tmp='sed -n '$num1'p '$file1
	adguardhome=$($tmp)
	echo $status$adguardhome
else
	echo ""
fi
}

ssr() {
	ssrstatus=''
	ssr=''
	ssrp=''
	[ -f "/etc/init.d/shadowsocksr" ] && ssr='Shadowsocksr '
	[ -f "/etc/init.d/passwall" ] && ssrp='Passwall '
	if [ ! "$ssr" == '' ]; then
		ssrstatus='Stopped'
		[ "$(ps -w |grep ssrplus/bin/ssr-|grep -v grep |wc -l)" -gt 0 ] && ssrstatus='Running'
	fi
	if [ ! "$ssrp" == '' ]; then
		ssrpstatus='Stopped'
		[ "$(ps -w |grep /etc/passwall |grep -v grep |wc -l)" -gt 0 ] && ssrpstatus='Running'
	fi
	if [ "$ssr" == '' -a "$ssrp" == '' ]; then
		echo "No VPN Server installed."
	else
		if [ "$ssrstatus" == 'Running' ]; then
			echo $ssr$ssrstatus
		elif [ "$ssrpstatus" == 'Running' ]; then
			echo $ssrp$ssrpstatus
		else
			echo "VPN "$ssrpstatus
		fi
	fi
}

ipsec_users() {
	if [ -f "/usr/sbin/ipsec" ]; then
		users=$(/usr/sbin/ipsec status|grep xauth|grep ESTABLISHED|wc -l)
		usersl2tp=$(top -bn1|grep options.xl2tpd|grep -v grep|wc -l)
		let "users=users+usersl2tp"
		[ "$users" == 0 ] && users='None'
	else
		users='None'
	fi
	echo $users
}

pptp_users() {
	if [ -f "/usr/sbin/pppd" ]; then
		users=$(top -bn1|grep options.pptpd|grep -v grep|wc -l)
#		let users=users-1
		[ "$users" == 0 ] && users='None'
	else
		users='None'
	fi
	echo $users
}

wg_users() {
file='/var/log/wg_users'
/usr/bin/wg >$file
m=$(sed -n '/peer/=' $file | sort -r -n )
k=$(cat $file|wc -l)
let "k=k+1"
s=$k
for n in $m
do 
	let "k=s-n"
	if [ $k -le 3 ] ;then 
		let "s=s-1"
		tmp='sed -i '$n,$s'd '$file
		$tmp
	else
		let "i=n+3"
		tmp='sed -n '$i'p '$file
		tmp=$($tmp|cut -d' ' -f6)
		[ "$tmp" == "hour," ] && tmp="hours,"
		[ "$tmp" == "minute," ] && tmp="minutes,"	
		case $tmp in
		hours,)
			let "s=s-1"
			tmp='sed -i '$n,$s'd '$file
			$tmp
			;;
		minutes,)
			tmp='sed -n '$i'p '$file
			tmp=$($tmp|cut -d' ' -f5)
			if [ $tmp -ge 3 ] ;then
				let "s=s-1"
				tmp='sed -i '$n,$s'd '$file
				$tmp
			fi
			;;
		esac
	fi
	s=$n
done
users=$(cat $file|grep peer|wc -l)
[ "$users" -eq 0 ] && users='None'
echo $users
}

wg() {
	if [ $(uci_get_by_name $NAME sysmonitor wgenable 0) == 0 ]; then
		if [ $(ifconfig |grep wg[0-9] |cut -c3-3|wc -l) != 0 ]; then
			wg_name=$(ifconfig |grep wg[0-9] |cut -c1-3)
			for x in $wg_name; do
			    ifdown $x &
			done
		fi
	else
		if [ $(ifconfig |grep wg[0-9] |cut -c3-3|wc -l) != 3 ]; then
			wg=$(ifconfig |grep wg[0-9] |cut -c1-3)
			wg_name="wg1 wg2 wg3"
			for x in $wg_name; do
				[ $(echo $wg|grep $x|wc -l) == 0 ] && ifup $x
			done
		fi
	fi
	wg=$(ifconfig |grep wg[0-9] |cut -c1-3)
	echo $wg
}

ad_del() {
	file1="/etc/AdGuardHome.yaml"
	num1=$(sed -n '/upstream_dns:/=' $file1)
	num2=$(sed -n '/upstream_dns_file:/=' $file1)
	let num1=num1+1
	let num2=num2-1
	tmp='sed -i '$num1','$num2'd '$file1
	[ $num1 -le $num2 ] && $tmp
}

ad_switch() {
	[ ! -f "/etc/init.d/AdGuardHome" ] && return
	adguardhome="  - "$1
	file1="/etc/AdGuardHome.yaml"
	if [ -f $file1 ]; then
		ad_del "upstream_dns:" "upstream_dns_file:"
		sed -i '/upstream_dns:/asqmshcn' $file1
		sed -i "s|sqmshcn|$adguardhome|g" $file1
		[ $(uci_get_by_name AdGuardHome AdGuardHome enabled 0) == 1 ] && /etc/init.d/AdGuardHome force_reload >/dev/null
	fi
}

switch_vpn() {
	if [ $(uci get sysmonitor.sysmonitor.vpn) == 0 ];  then
		onoff_vpn
	else
		if [ "$(ps -w|grep /etc/passwall|grep -v grep|wc -l)" == 0 ]; then
			if [ -f "/etc/init.d/passwall" ]; then
				uci set passwall.@global[0].enabled=1
				uci commit passwall
				/etc/init.d/passwall restart &
				echo "Passwall"
			else
				[ -f "/etc/init.d/shadowsocksr" ] && /etc/init.d/shadowsocksr restart &
				echo "Shadowsocksr"
			fi
			
		elif [ "$(ps -w|grep ssrplus/bin/ssr-|grep -v grep|wc -l)" == 0 ]; then
			[ -f "/etc/init.d/shadowsocksr" ] && /etc/init.d/shadowsocksr restart &
			echo "Shadowsocksr"
		fi
	fi
}

onoff_vpn() {
	ssr=$(ps |grep /etc/passwall |grep -v grep |wc -l)
	[ $ssr -lt 1 ] && ssr=$(ps -w |grep ssrplus/bin/ssr-|grep -v grep |wc -l)
	if [ $ssr -gt 0 ];  then
		# Stop Passwall
		if [ "$(ps |grep /etc/passwall |grep -v grep |wc -l)" -gt 0 ]; then
			uci set passwall.@global[0].enabled=0
			uci commit passwall
			/etc/init.d/passwall stop &
		fi
		# Stop Shadowsocksr
		[ "$(ps |grep ssrplus/bin/ssr-|grep -v grep |wc -l)" -gt 0 ] && /etc/init.d/shadowsocksr stop
	else
		if [ -f "/etc/init.d/passwall" ]; then
			if [ "$(ps |grep /etc/passwall |grep -v grep |wc -l)" -lt 1 ]; then
			if [ $(uci get passwall.@global[0].tcp_node) != 'nil' ]; then
				uci set passwall.@global[0].enabled=1
				uci commit passwall
				/etc/init.d/passwall restart &
			fi
			fi			
		elif [ -f "/etc/init.d/shadowsocksr" ]; then
			if [ "$(ps |grep ssrplus/bin/ssr-|grep -v grep |wc -l)" -lt 1 ]; then
				/etc/init.d/shadowsocksr restart &
			fi
		else
			touch /tmp/sysmonitor
		fi		
	fi
}
switch_ipsecfw() {
	if [ $(uci get firewall.@zone[0].masq) == 1 ]; then
		uci set firewall.@zone[0].mtu_fix=0
		uci set firewall.@zone[0].masq=0
	else
		uci set firewall.@zone[0].mtu_fix=1
		uci set firewall.@zone[0].masq=1
	fi
	uci commit firewall
	/etc/init.d/firewall restart 2>/dev/null
}

getip() {
	ip=$(ip -o -4 addr list br-lan | cut -d ' ' -f7 | cut -d'/' -f1)
	echo $ip >/www/ip.html
	echo $ip
}

getip6() {
	ip=$(ip -o -6 addr list br-lan | cut -d ' ' -f7| cut -d'/' -f1 | head -n1)
	echo $ip >/www/ip6.html
	echo $ip
}

smartdns() {
	[ -f /tmp/smartdns.cache ] && rm /tmp/smartdns.cache
	[ $(ps |grep smartdns|grep -v grep|wc -l) -gt 0 ] && /etc/init.d/smartdns restart
}

service_smartdns() {
	if [ "$(uci get sysmonitor.sysmonitor.smartdns)" == 0 ]; then
		uci set sysmonitor.sysmonitor.smartdns=1
	else
		uci set sysmonitor.sysmonitor.smartdns=0
	fi
	uci commit sysmonitor
	set_smartdns
}

start_smartdns() {
	uci set sysmonitor.sysmonitor.smartdns=1
	uci commit sysmonitor
	uci set smartdns.@smartdns[0].enabled='1'
	uci set smartdns.@smartdns[0].seconddns_enabled='1'
	uci set smartdns.@smartdns[0].port=$(uci get sysmonitor.sysmonitor.smartdnsPORT)
	uci set smartdns.@smartdns[0].seconddns_port=$1
	uci commit smartdns
	/etc/init.d/smartdns start
}

set_smartdns() {
	if [ -f "/etc/init.d/smartdns" ]; then
		if [ $(uci get sysmonitor.sysmonitor.smartdnsAD) == 1 ];  then
			sed -i s/".*$conf-file.*$"/"conf-file \/etc\/smartdns\/anti-ad-for-smartdns.conf"/ /etc/smartdns/custom.conf
		else
			sed -i s/".*$conf-file.*$"/"#conf-file \/etc\/smartdns\/anti-ad-for-smartdns.conf"/ /etc/smartdns/custom.conf	
		fi
		[ -f /tmp/smartdns.cache ] && rm /tmp/smartdns.cache
		if [ $(uci get sysmonitor.sysmonitor.smartdns) == 1 ];  then
			port='5335'
			sed -i '/address/d' /etc/smartdns/custom.conf
			echo "address /NAS/192.168.1.8" >> /etc/smartdns/custom.conf
			if [ -f "/etc/init.d/shadowsocksr" ]; then
				[ "$(uci get shadowsocksr.@global[0].pdnsd_enable)" -ne 0 ] && port='8653'		
			fi
			[ -f "/etc/init.d/passwall" ] && port='8653'	
			start_smartdns $port
		else
			vpn=$(ps |grep ssrplus/bin/ssr-|grep -v grep|wc -l)
			[ "$vpn" == 0 ] && vpn=$(ps |grep /etc/passwall|grep -v grep|wc -l)
			if [ "$vpn" == 0 ]; then
				touch /tmp/smartdns_stop
			else
				if [ "$(uci get shadowsocksr.@global[0].pdnsd_enable)" -ne 0 ]; then
					touch /tmp/smartdns_stop
				else
					start_smartdns '5335'
				fi
				if [ "$(uci get passwall.@global[0].dns_shunt)" == 'smartdns' ]; then
					start_smartdns '8653'
				else
					touch /tmp/smartdns_stop
				fi
			fi
			if [ -f "/tmp/smartdns_stop" ]; then
				rm /tmp/smartdns_stop
				/etc/init.d/smartdns stop >/dev/null 2>&1
#				uci del dhcp.@dnsmasq[0].server
#				uci set dhcp.@dnsmasq[0].port=''
#				uci set dhcp.@dnsmasq[0].noresolv=0
#				uci commit dhcp
#				/etc/init.d/dnsmasq restart
			fi

		fi
	fi
}

selvpn() {
case $1 in
p)
	[ $(uci get passwall.@global[0].enabled) == 1 ] && uci set sysmonitor.sysmonitor.vpnp=1
	uci set sysmonitor.sysmonitor.vpns=0		
	uci commit sysmonitor
	[ -f /etc/init.d/shadowsocksr ] && /etc/init.d/shadowsocksr stop
	;;
s)
	[ ! $(uci get shadowsocksr.@global[0].global_server) == 'nil' ] && uci set sysmonitor.sysmonitor.vpns=1
	uci set sysmonitor.sysmonitor.vpnp=0
	uci commit sysmonitor
	[ -f /etc/init.d/passwall ] && /etc/init.d/passwall stop
	;;
esac
	set_smartdns
}

passwall() {
	if [ "$(uci get sysmonitor.sysmonitor.vpnp)" == 0 ]; then
		uci set sysmonitor.sysmonitor.vpnp=1
		uci set sysmonitor.sysmonitor.vpns=0
	else
		uci set sysmonitor.sysmonitor.vpnp=0
	fi
	uci commit sysmonitor
	vpn
}

shadowsocksr() {
	if [ "$(uci get sysmonitor.sysmonitor.vpns)" == 0 ]; then
		uci set sysmonitor.sysmonitor.vpns=1
		uci set sysmonitor.sysmonitor.vpnp=0
	else
		uci set sysmonitor.sysmonitor.vpns=0
	fi
	uci commit sysmonitor
	vpn
}

vpn() {
	if [ $(uci get sysmonitor.sysmonitor.vpns) == 1 ];  then
		[ -f "/tmp/set_smartdns" ] && rm /tmp/set_smartdns
		if [ $(ps |grep ssrplus/bin/ssr-|grep -v grep|wc -l) -eq 0 ]; then
			[ -f "/etc/init.d/shadowsocksr" ] && /etc/init.d/shadowsocksr start &
		fi
	else
		touch /tmp/set_smartdns
		[ $(ps |grep ssrplus/bin/ssr-|grep -v grep|wc -l) -gt 0 ] && /etc/init.d/shadowsocksr stop &
	fi
	if [ $(uci get sysmonitor.sysmonitor.vpnp) == 1 ];  then
		[ -f "/tmp/set_smartdns" ] && rm /tmp/set_smartdns
		if [ $(ps |grep /etc/passwall|grep -v grep|wc -l) -eq 0 ]; then
			[ -f "/etc/init.d/passwall" ] && /etc/init.d/passwall start &
		fi
	else
		touch /tmp/set_smartdns
		[ $(ps |grep /etc/passwall|grep -v grep|wc -l) -gt 0 ] && /etc/init.d/passwall stop &
	fi
	if [ -f "/tmp/set_smartdns" ] ; then
		rm /tmp/set_smartdns
		set_smartdns
	fi
}

arg1=$1
shift
case $arg1 in
selvpn)
	selvpn $1
	;;
set_smartdns)
	set_smartdns
	;;
service_smartdns)
	service_smartdns
	;;
smartdns)
	smartdns
	;;
passwall)
	passwall
	;;
shadowsocksr)
	shadowsocksr
	;;
getip)
	getip
	;;
getip6)
	getip6
	;;
agh)
	agh
	;;
ssr)
	ssr
	;;
ipsec)
	ipsec_users
	;;
pptp)
	pptp_users
	;;
wg)
	wg_users
	;;
onoff_vpn)
	onoff_vpn
	;;
switch_vpn)
	switch_vpn
	;;
switch_ipsecfw)
	switch_ipsecfw
	;;
ad_switch)
	ad_switch $1
	;;
test)
	echo $1

	;;

esac
