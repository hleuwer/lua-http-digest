local md5sum, md5_library
local fmt = string.format

do -- select MD5 library

    local ok, mod = pcall(require, "crypto")
    if ok then
        local digest = (mod.evp or mod).digest
        if digest then
            md5sum = function(str) return digest("md5", str) end
            md5_library = "crypto"
        end
    end

    if not md5sum then
        ok, mod = pcall(require, "md5")
        if ok then
            local md5 = (type(mod) == "table") and mod or _G.md5
            md5sum = md5.sumhexa or md5.digest
            if md5sum then md5_library = "md5" end
        end
    end

    if not md5sum then
        ok = pcall(require, "digest") -- last because using globals
        if ok and _G.md5 then md5sum = _G.md5.digest end
        if md5sum then md5_library = "digest" end
    end

end

assert(md5sum, "cannot find supported md5 module")

local s_http = require "socket.http"
local s_url = require "socket.url"
local ltn12 = require "ltn12"

local hash = function(...)
    return md5sum(table.concat({...}, ":"))
end

--- Parse the value part of the WWW-Authenticate header into a table.
local parse_header = function(h)
    local r = {}
    for k, v in (h .. ','):gmatch("(%w+)=(.-),") do
        if v:sub(1, 1) == '"' then -- strip quotes
            r[k:lower()] = v:sub(2, -2)
        else r[k:lower()] = v end
    end
    return r
end

--- Helper to build the Authorization header. `t` is a table of tables.
local make_digest_header = function(t)
    local r = {}
    for i = 1, #t do
        local x = t[i]
        if x.unquote then
            r[i] =  x[1] .. '=' .. x[2]
        else
            r[i] = x[1] .. '="' .. x[2] .. '"'
        end
    end
    return "Digest " .. table.concat(r, ', ')
end

--- Copy a table (one layer deep).
local hcopy = function(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

--- Main logic. `params` is always a table and can be modified.
local _request = function(params)
    if not params.url then error("missing URL") end
    local url = s_url.parse(params.url)
    local user, password = url.user, url.password
    local handler = params.handler
    if not (user and password) then
        error("missing credentials in URL")
    end
    url.user, url.password, url.authority, url.userinfo = nil, nil, nil, nil
    params.url = s_url.build(url)
    local ghost_source
    if params.source then
        local ghost_chunks = {}
        local ghost_capture = function(x)
            if x then ghost_chunks[#ghost_chunks+1] = x end
            return x
        end
        local ghost_i = 0
        ghost_source = function()
            ghost_i = ghost_i+1
            return ghost_chunks[ghost_i]
        end
        params.source = ltn12.source.chain(params.source, ghost_capture)
    end
    local _http
    if handler ~= nil then
       _http = require "copas.http"
    else
       _http = s_http
    end
    local b, c, h = _http.request(params)
    if (c == 401) and h["www-authenticate"] then
        local ht = parse_header(h["www-authenticate"])
        assert(ht.realm and ht.nonce)
        if ht.qop ~= "auth" then
            return nil, fmt("unsupported qop (%s)", tostring(ht.qop))
        end
        if ht.algorithm and (ht.algorithm:lower() ~= "md5") then
            return nil, fmt("unsupported algo (%s)", tostring(ht.algorithm))
        end
        local nc, cnonce = "00000001", fmt("%08x", os.time())
        local uri = s_url.build({path = url.path, query = url.query})
        local method = params.method or "GET"
        local response = hash(
            hash(user, ht.realm, password),
            ht.nonce,
            nc,
            cnonce,
            "auth",
            hash(method, uri)
        )
        params.headers = params.headers or {}
        local auth_header = {
            {"username", user},
            {"realm", ht.realm},
            {"nonce", ht.nonce},
            {"uri", uri},
            {"cnonce", cnonce},
            {"nc", nc, unquote=true},
            {"qop", "auth"},
            {"algorithm", "MD5"},
            {"response", response},
        }
        if ht.opaque then
            table.insert(auth_header, {"opaque", ht.opaque})
        end
        params.headers.authorization = make_digest_header(auth_header)
        if not params.headers.cookie and h["set-cookie"] then
            -- not really correct but enough for httpbin
            local cookie = (h["set-cookie"] .. ";"):match("(.-=.-)[;,]")
            if cookie then
                params.headers.cookie = "$Version: 0; " .. cookie .. ";"
            end
        end
        if params.source then params.source = ghost_source end
	b, c, h = _http.request(params)
	if type(handler) == "function" then
	   if params._magic ~= nil then
	      return handler(table.concat(params._magic), c, h, params.opaque)
	   else
	      return handler(b, c, h, params.opaque)
	   end
	else
	   return b, c, h
	end
    else
       if type(handler) == "function" then
	  if params._magic ~= nil then
	     return handler(table.concat(params._magic), c, h, params.opaque)
	  else
	     return handler(b, c, h, params.opaque)
	  end
       else
	  return b, c, h
       end
    end
end

local request = function(params, handler, opaque)
   local t = type(params)
   if t == "table" then
      if type(params.handler) == "function" then
	 assert(type(params.handler) == "function", "Handler must be of type function.")
	 local copas = require "copas"
	 copas.addthread(_request, params)
      else
	 return _request(hcopy(params))
      end
   elseif t == "string" then
      local r = {}
      local params = {url = params, sink = ltn12.sink.table(r), handler = handler, opaque = opaque, _magic = r}
      if type(handler) == "function" then
	 local copas = require "copas"
	 copas.addthread(_request, hcopy(params))
      else
	 local _, c, h = _request(hcopy(params))
	 return table.concat(r), c, h
      end
   else
      error(fmt("unexpected type %s", t))
   end
end


return {
    md5_library = md5_library,
    request = request,
}
