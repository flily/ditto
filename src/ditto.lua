
--[[

Ditto - An HTTP proxy with DNS cache.

Authors:    Flily Hsu (flily.hsu@qq.com)
Updated:    2014-07-22

--]]

local M = { }

local function is_domain(host)
    local pattern = "^(%d+%.%d+%.%d+%.%d+)(%:?)(%d*)$"
    local ip, colon, port = host:match(pattern)
    if nil ~= ip then
        return false
    end

    return true
end

function M.main()
    local host = ngx.var.http_host
    if is_domain(host) then
        host_ip = dns.get_addr(host)
        ngx.var.host_ip = host_ip
    else
        ngx.var.host_ip = host
    end
end

return M
