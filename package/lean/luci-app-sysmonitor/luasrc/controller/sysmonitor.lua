-- Copyright (C) 2017
-- Licensed to the public under the GNU General Public License v3.

module("luci.controller.sysmonitor", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/sysmonitor") then
		return
	end
	entry({"admin", "sys"}, firstchild(), "SYS", 10).dependent = false
	entry({"admin", "sys","sysmonitor"}, alias("admin", "sys","sysmonitor", "settings"),_("SYSMonitor"), 20).dependent = true
	entry({"admin", "sys", "sysmonitor", "settings"}, cbi("sysmonitor/setup"),_("General Settings"), 30).leaf = true
	entry({"admin", "sys", "sysmonitor", "wgusers"},cbi("sysmonitor/wgusers"),_("WGusers"), 50).leaf = true
	entry({"admin", "sys", "sysmonitor", "log"},cbi("sysmonitor/log"),_("Log"), 60).leaf = true

	entry({"admin", "sys", "sysmonitor", "ip_status"}, call("action_ip_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wireguard_status"}, call("action_wireguard_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_status"}, call("action_service_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wg_users"}, call("wg_users")).leaf = true
	entry({"admin", "sys", "sysmonitor", "smartdns_cache"}, call("smartdns_cache")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_shadowsocksr"}, call("shadowsocksr")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_passwall"}, call("passwall")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_lighttpd"}, call("service_lighttpd")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_smartdns"}, call("service_smartdns")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_button"}, call("service_button")).leaf = true
end

function get_log()
	luci.http.write(luci.sys.exec("[ -f '/var/log/sysmonitor.log' ] && cat /var/log/sysmonitor.log"))
end

function clear_log()
	luci.sys.exec("echo '' > /var/log/sysmonitor.log")
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor","log"))
end

function action_ip_status()
	ip6=' IP6: ['..luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip6")..']'
	iplan='<br>LAN: '..luci.sys.exec("uci get network.lan.ipaddr")..' gateway:'..luci.sys.exec("uci get network.lan.gateway")..' <font color=9699cc>dns:'..luci.sys.exec("uci get network.lan.dns")..'</font>'
	ipwan='<br>WAN:'..luci.sys.exec("uci get network.wan.ipaddr")..' gateway:'..luci.sys.exec("uci get network.wan.gateway")..' <font color=9699cc>dns:'..luci.sys.exec("uci get network.wan.dns")..'</font>'
	ipwifi='<br>WIFI: '..luci.sys.exec("uci get network.wifi.ipaddr")..' <font color=9699cc>dns:'..luci.sys.exec("uci get network.wifi.dns")..'</font>'
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ip_state = ip6..iplan..ipwan..ipwifi
	})
end

function action_service_status()
	lighttpd=''
	if nixio.fs.access("/etc/init.d/lighttpd") then
	tmp = tonumber(luci.sys.exec("ps |grep lighttpd|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"
	end
	lighttpd = ' <font color='..color..'>Lighttpd</font>'
	end
	smartdns=''
	if nixio.fs.access("/etc/init.d/smartdns") then
	tmp = tonumber(luci.sys.exec("ps |grep smartdns|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"
	end
	smartdns = ' <font color='..color..'>SmartDNS<a href="/cgi-bin/luci/admin/services/smartdns" target="_blank">--></a></font>'
	end
	vpn = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getvpn")
	if ( vpn == '' ) then
		vpn = ' <font color=red>VPN</font>'
	else
		vpn = ' <font color=green>VPN-'..vpn..'<a href="/cgi-bin/luci/admin/services/'..string.lower(vpn)..'" target="_blank">--></a></font>'
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_state = lighttpd..smartdns..vpn
	})
end

function service_button()
	button='<button class="button1"><a href="/cgi-bin/luci/admin/services/ttyd" target="_blank">Terminal</a></button>'
	buttonl=''
	if nixio.fs.access("/etc/init.d/lighttpd") then
		buttonl=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_lighttpd">Lighttpd</a></button>'
	end
	buttond=''
	if nixio.fs.access("/etc/init.d/smartdns") then
		buttond=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_smartdns">SmartDNS</a></button>'
	end
	buttons=''
	if nixio.fs.access("/etc/init.d/shadowsocksr") then
		buttons=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_shadowsocksr">Shadowsocksr</a></button>'
	end
	buttonp=''
	if nixio.fs.access("/etc/init.d/passwall") then
		buttonp=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_passwall">Passwall</a></button>'
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_button = button..buttonl..buttond..buttons..buttonp
	})
end

function shadowsocksr()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh shadowsocksr")
end

function passwall()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh passwall")
end

function smartdns_cache()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh smartdns_cache")
end

function service_lighttpd()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/etc/init.d/lighttpd start")	
end

function service_smartdns()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh service_smartdns")	
end

function wg_users()
	luci.http.write(luci.sys.exec("[ -f '/var/log/wg_users' ] && cat /var/log/wg_users"))
end

function action_wireguard_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		wireguard_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh wg")
	})
end

