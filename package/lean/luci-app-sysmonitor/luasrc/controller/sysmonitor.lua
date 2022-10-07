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
	entry({"admin", "sys", "sysmonitor", "wg_status"}, call("action_wg_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wireguard_status"}, call("action_wireguard_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_status"}, call("action_service_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wg_users"}, call("wg_users")).leaf = true
	entry({"admin", "sys", "sysmonitor", "smartdns"}, call("smartdns")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_shadowsocksr"}, call("shadowsocksr")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_passwall"}, call("passwall")).leaf = true
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
	ip = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ip_state = ip..'<font color=9699cc> ['..luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip6")..']</font> gateway:'..luci.sys.exec("uci get network.lan.gateway")
	})
end

function action_service_status()
	tmp = tonumber(luci.sys.exec("ps |grep smartdns|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"
	end
	smartdns = '<font color='..color..'>SmartDNS<a href="/cgi-bin/luci/admin/services/smartdns" target="_blank">--></a></font>'
	vpnp=''
	if nixio.fs.access("/etc/config/passwall") then
		vpn="Passwall"
		tmp = tonumber(luci.sys.exec("ps |grep /etc/passwall|grep -v grep|wc -l"))
		if ( tmp == 0 ) then
			color="red"
		else
			color="green"
		end
		vpnp = ' <font color='..color..'>VPN('..vpn..')<a href="/cgi-bin/luci/admin/services/'..string.lower(vpn)..'" target="_blank">--></a></font>'
	end
	vpns=''
	if nixio.fs.access("/etc/config/shadowsocksr") then
		vpn="Shadowsocksr"
		tmp = tonumber(luci.sys.exec("ps |grep ssrplus/bin/ssr-|grep -v grep|wc -l"))
		if ( tmp == 0 ) then
			color="red"
		else
			color="green"
		end
		vpns = ' <font color='..color..'>VPN('..vpn..')<a href="/cgi-bin/luci/admin/services/'..string.lower(vpn)..'" target="_blank">--></a></font>'
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_state = smartdns..vpnp..vpns
	})
end

function service_button()
	button='<button class="button1"><a href="/cgi-bin/luci/admin/services/ttyd" target="_blank">Terminal</a></button> <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_smartdns">SmartDNS</a></button> <button class=button1><a href="/cgi-bin/luci/admin/sys/sysmonitor/smartdns">Clean DNS cache</a></button>'
	buttons=''
	if nixio.fs.access("/etc/config/shadowsocksr") then
		buttons=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_shadowsocksr">Shadowsocksr</a></button>'
	end
	buttonp=''
	if nixio.fs.access("/etc/config/passwall") then
		buttonp=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_passwall">Passwall</a></button>'
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_button = button..buttons..buttonp
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

function smartdns()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh smartdns")
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

