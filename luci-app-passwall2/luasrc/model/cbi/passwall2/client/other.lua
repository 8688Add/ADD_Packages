local api = require "luci.passwall2.api"
local appname = api.appname
local fs = api.fs
local has_v2ray = api.is_finded("v2ray")
local has_xray = api.is_finded("xray")
local has_fw3 = api.is_finded("fw3")
local has_fw4 = api.is_finded("fw4")

m = Map(appname)

-- [[ Delay Settings ]]--
s = m:section(TypedSection, "global_delay", translate("Delay Settings"))
s.anonymous = true
s.addremove = false

---- Delay Start
o = s:option(Value, "start_delay", translate("Delay Start"), translate("Units:seconds"))
o.default = "1"
o.rmempty = true

---- Open and close Daemon
o = s:option(Flag, "start_daemon", translate("Open and close Daemon"))
o.default = 1
o.rmempty = false

--[[
---- Open and close automatically
o = s:option(Flag, "auto_on", translate("Open and close automatically"))
o.default = 0
o.rmempty = false

---- Automatically turn off time
o = s:option(ListValue, "time_off", translate("Automatically turn off time"))
o.default = nil
o:depends("auto_on", true)
o:value(nil, translate("Disable"))
for e = 0, 23 do o:value(e, e .. translate("oclock")) end

---- Automatically turn on time
o = s:option(ListValue, "time_on", translate("Automatically turn on time"))
o.default = nil
o:depends("auto_on", true)
o:value(nil, translate("Disable"))
for e = 0, 23 do o:value(e, e .. translate("oclock")) end

---- Automatically restart time
o = s:option(ListValue, "time_restart", translate("Automatically restart time"))
o.default = nil
o:depends("auto_on", true)
o:value(nil, translate("Disable"))
for e = 0, 23 do o:value(e, e .. translate("oclock")) end
--]]

-- [[ Forwarding Settings ]]--
s = m:section(TypedSection, "global_forwarding", translate("Forwarding Settings"))
s.anonymous = true
s.addremove = false

---- TCP No Redir Ports
o = s:option(Value, "tcp_no_redir_ports", translate("TCP No Redir Ports"))
o.default = "disable"
o:value("disable", translate("No patterns are used"))
o:value("1:65535", translate("All"))

---- UDP No Redir Ports
o = s:option(Value, "udp_no_redir_ports", translate("UDP No Redir Ports"),
	"<font color='red'>" ..
	translate("Fill in the ports you don't want to be forwarded by the agent, with the highest priority.") ..
	"</font>")
o.default = "disable"
o:value("disable", translate("No patterns are used"))
o:value("1:65535", translate("All"))

---- TCP Redir Ports
o = s:option(Value, "tcp_redir_ports", translate("TCP Redir Ports"))
o.default = "22,25,53,143,465,587,853,993,995,80,443"
o:value("1:65535", translate("All"))
o:value("22,25,53,143,465,587,853,993,995,80,443", translate("Common Use"))
o:value("80,443", translate("Only Web"))

---- UDP Redir Ports
o = s:option(Value, "udp_redir_ports", translate("UDP Redir Ports"))
o.default = "1:65535"
o:value("1:65535", translate("All"))

---- Use nftables
o = s:option(ListValue, "use_nft", translate("Firewall tools"))
o.default = "0"
if has_fw3 then
	o:value("0", "IPtables")
end
if has_fw4 then
	o:value("1", "NFtables")
end

if (os.execute("lsmod | grep -i REDIRECT >/dev/null") == 0 and os.execute("lsmod | grep -i TPROXY >/dev/null") == 0) or (os.execute("lsmod | grep -i nft_redir >/dev/null") == 0 and os.execute("lsmod | grep -i nft_tproxy >/dev/null") == 0) then
	o = s:option(ListValue, "tcp_proxy_way", translate("TCP Proxy Way"))
	o.default = "redirect"
	o:value("redirect", "REDIRECT")
	o:value("tproxy", "TPROXY")
	o:depends("ipv6_tproxy", false)

	o = s:option(ListValue, "_tcp_proxy_way", translate("TCP Proxy Way"))
	o.default = "tproxy"
	o:value("tproxy", "TPROXY")
	o:depends("ipv6_tproxy", true)
	o.write = function(self, section, value)
		return self.map:set(section, "tcp_proxy_way", value)
	end

	if os.execute("lsmod | grep -i ip6table_mangle >/dev/null") == 0 or os.execute("lsmod | grep -i nft_tproxy >/dev/null") == 0 then
		---- IPv6 TProxy
		o = s:option(Flag, "ipv6_tproxy", translate("IPv6 TProxy"),
			"<font color='red'>" ..
			translate("Experimental feature. Make sure that your node supports IPv6.") ..
			"</font>")
		o.default = 0
		o.rmempty = false
	end
end

o = s:option(Flag, "accept_icmp", translate("Hijacking ICMP (PING)"))
o.default = 0

o = s:option(Flag, "accept_icmpv6", translate("Hijacking ICMPv6 (IPv6 PING)"))
o:depends("ipv6_tproxy", true)
o.default = 0

if has_v2ray or has_xray then
	s = m:section(TypedSection, "global_xray", "V2Ray/Xray " .. translate("Settings"))
	s.anonymous = true
	s.addremove = false

	o = s:option(Flag, "sniffing", translate("Sniffing"), translate("When using the shunt, must be enabled, otherwise the shunt will invalid."))
	o.default = 1
	o.rmempty = false

	if has_xray then
		o = s:option(Flag, "route_only", translate("Sniffing Route Only"))
		o.default = 0
		o:depends("sniffing", true)

		local domains_excluded = string.format("/usr/share/%s/domains_excluded", appname)
		o = s:option(TextValue, "no_sniffing_hosts", translate("No Sniffing Lists"), translate("Hosts added into No Sniffing Lists will not resolve again on server."))
		o.rows = 15
		o.wrap = "off"
		o.cfgvalue = function(self, section) return fs.readfile(domains_excluded) or "" end
		o.write = function(self, section, value) fs.writefile(domains_excluded, value:gsub("\r\n", "\n")) end
		o.remove = function(self, section, value)
			if s.fields["route_only"]:formvalue(section) == "0" then
				fs.writefile(domains_excluded, "")
			end
		end
		o:depends({sniffing = true, route_only = false})

		o = s:option(Value, "buffer_size", translate("Buffer Size"), translate("Buffer size for every connection (kB)"))
		o.datatype = "uinteger"
	end
end

return m
