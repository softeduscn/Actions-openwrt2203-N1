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
	entry({"admin", "sys", "sysmonitor", "log"},cbi("sysmonitor/log"),_("Log"), 60).leaf = true

	entry({"admin", "sys", "sysmonitor", "ip_status"}, call("action_ip_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "get_log"}, call("get_log")).leaf = true
end

function get_log()
	luci.http.write(luci.sys.exec("[ -f '/var/log/sysmonitor.log' ] && cat /var/log/sysmonitor.log"))
end

function action_ip_status()
	ip = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ip_state = ip..'<font color=9699cc> ['..luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip6")..'] </font><button class=button1><a href="http://'..ip..':7681" target="_blank" title="Open terminal">Open terminal</a></button>'
	})
end

