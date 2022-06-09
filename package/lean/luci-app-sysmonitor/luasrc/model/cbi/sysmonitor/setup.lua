
local m, s
local global = 'sysmonitor'
local uci = luci.model.uci.cursor()
--ip = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip")
m = Map("sysmonitor",translate("System Monitor"))

m:append(Template("sysmonitor/status"))

s = m:section(TypedSection, "sysmonitor", translate("System Settings"))
s.anonymous = true
--s.description ='<button class="button1"><a href="http://'..ip..':7681" target="_blank" title="Open a ttyd terminal">' .. translate("Open Terminal") .. '</a></button>'

o=s:option(Flag,"enable", translate("Enable"))
o.rmempty=false

o=s:option(Flag,"bbr", translate("BBR Enable"))
o.rmempty=false

if nixio.fs.access("/etc/init.d/smartdns") then
o=s:option(Flag,"smartdnsAD", translate("SmartDNS-AD Enable"))
o.rmempty=false
end

if nixio.fs.access("/etc/init.d/ddns") then
o=s:option(Flag,"ddnsmonitor", translate("DDNS Monitor"))
o.rmempty=false
end

o = s:option(Value, "homeip", translate("Home IP Address"))
o.description = translate("IP for Home(192.168.1.1)")
o.datatype = "or(host)"
o.rmempty = false

--[[
o = s:option(Value, "vpnip", translate("VPN IP Address"))
o.description = translate("IP for VPN Server(192.168.1.110)")
o.datatype = "or(host)"
o.rmempty = false
--]]

return m
