
--[[

DNS query wrap

Authors:    Flily Hsu (flily.hsu@qq.com)
Updated:    2013-12-26

--]]

local res = require 'resolver'

local M = { }

--[[
Initialize DNS module, resolver of resty.
--]]
function M.init(name_servers, timeout)
    local server = nil
    local time = timeout or 2000      -- 2 sec

    if "string" == type(name_servers) then
        server = { name_servers }
    elseif nil == name_servers then
        server = { "8.8.8.8" }
    elseif "table" == type(name_servers) then
        server = name_servers
    else
        error("Unknown value of name_servers, got: " .. tostring(name_servers))
    end

    M.parse_hosts("/etc/hosts")

    M.name_servers = server
    M.timeout      = time
end

--[[
Parse DNS servers from resolv.conf

Format:
nameserver 1.2.3.4
--]]
function M.parse_resolv(filename)
    local server, sc = { }, 1
    local fd = io.open(filename, "r")
    if nil == fd then return nil end

    while true do
        local line = fd:read()
        if nil == line then break end
        local ip = line:match("nameserver +(%d+%.%d+%.%d+%.%d+)")
        if nil ~= ip then
            server[sc] = ip
            sc = sc + 1
        end
    end
    fd:close()
    return server
end

function M.parse_hosts(filename)
    local server, sc = { }, 1
    local fd = io.open(filename, "r")
    local dns = ngx.shared.dns
    if nil == fd then return { } end

    while true do
        local line = fd:read()
        if nil == line then break end
        
        if "" ~= line and not line:match("^%s*$") and not line:match("%s*#") then
            local _, i, ip = line:find("^%s*([%x%.%:]+)")
            local hosts = line:sub(i+1)
            for w in hosts:gmatch("[%w%.%-]+") do
                dns:set(w, ip)
                print(w, ip)
            end
        end
    end
    fd:close()
    return server
end

--[[
Create an instance of DNS resolver
--]]
function M.create()
    local resolver, err = res:new{
        nameservers = M.name_servers,
        timeout     = M.timeout
    }

    if nil == resolver then
        ngx.log(ngx.ERR, "Initialize DNS resolver failed, message: ", tostring(err))
    end

    return resolver
end

--[[
Resolve and fetch address of specified domain name.

The first IP address in DNS answer will be returned.
--]]
function M.get_addr(name)
    local dns = ngx.shared.dns

    local ip, _, stale = dns:get_stale(name)
    if ip and not stale then return ip end

    ngx.log(ngx.ERR, "DNS cache expired")
    local resolver = M.create()
    if nil == resolver then return nil end

    local result, err = resolver:query(name)
    if nil == result then
        ngx.log(ngx.ERR, string.format("failed to resolve name '%s': %s", name, tostring(err)))
        return nil
    end

    for _, ans in ipairs(result) do
        if nil ~= ans.address then
            dns:set(name, ans.address, 300)
            return ans.address
        end
    end

    ngx.log(ngx.ERR, string.format("No answer to DNS query name '%s'.", name))
    return nil
end

return M
