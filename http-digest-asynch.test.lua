local cwtest = require "cwtest"
local ltn12 = require "ltn12"
local http_digest = require "http-digest"
local copas = require "copas"
local pretty = require "pl.pretty"

local json_decode
do -- Find a JSON parser
    local ok, json = pcall(require, "cjson")
    if not ok then ok, json = pcall(require, "json") end
    json_decode = json.decode
    assert(ok and json_decode, "no JSON parser found :(")
end

local T = cwtest.new()

local b, c, _
local url = "http://user:passwd@httpbin.org/digest-auth/auth/user/passwd"
local badurl = "http://user:nawak@httpbin.org/digest-auth/auth/user/passwd"
local aggr = true
local N = 5

if aggr ==  true then
   T:start("Test started")
end
local debug = false
local function dprint(fmt, ...)
   if debug == true then
      print(">> "..string.format(fmt, ...))
   end
end
----------------------------------------------------------------------
-- simple interface 
if aggr == false then
   T:start("simple interface")
end
http_digest.request(url,
		    function(b, c, h)
		       dprint("body=%s status=%d header=%s", b, c, pretty.write(h,""))
		       T:eq( c, 200 )
		       T:eq( json_decode(b), {authenticated = true, user = "user"} )
		    end
)
if aggr == false then
   repeat
      copas.step()
   until copas.finished() == true
   T:done()
end

----------------------------------------------------------------------
-- simple interface -- bad url
if aggr == false then
   T:start("simple interface - bad url")
end
http_digest.request(badurl,
		    function(b, c, h)
		       dprint("body=%s status=%d header=%s", b, c, pretty.write(h,""))
		       T:eq( c, 401 )
		    end
)
if aggr == false then
   repeat
      copas.step()
   until copas.finished() == true
   T:done()
end

----------------------------------------------------------------------
-- generic interface -- asynchronous request possible
if aggr == false then
   T:start("generic interface - asynchronous")
end
b1 = {}
http_digest.request {
    url = url,
    sink = ltn12.sink.table(b1),
    handler = function(_b, c, h)
       dprint("body=%s status=%d header=%s", _b, c, pretty.write(h,""))
       T:eq( c, 200 )
       local b = table.concat(b1)
       T:eq( json_decode(b), {authenticated = true, user = "user"} )
    end
}
if aggr == false then
   repeat
      copas.step()
   until copas.finished() == true
   T:done()
end
----------------------------------------------------------------------
-- generic interface - asynchronous - bad url
if aggr == false then
   T:start("generic interface - asynchronous - bad url")
end
http_digest.request({
      url = badurl,
      handler = function(_b, c, h)
	 dprint("body=%s status=%d header=%s", _b, c, pretty.write(h,""))
	 T:eq(c, 401)
      end
})

if aggr == false then
   repeat
      copas.step()
   until copas.finished() == true
   T:done()
end

----------------------------------------------------------------------
-- with ltn12 source
if aggr == false then
   T:start("generic interface - asynchronous - with ltn source")
end

b2 = {}
http_digest.request {
    url = url,
    sink = ltn12.sink.table(b2),
    source = ltn12.source.string("test"),
    headers = {["content-length"] = 4}, -- 0 would work too
    handler = function(_b, c, h)
       dprint("body=%s status=%d header=%s", _b, c, pretty.write(h,""))
       T:eq( c, 200 )
       local b = table.concat(b2)
       T:eq( json_decode(b), {authenticated = true, user = "user"} )
    end
}

repeat
   copas.step()
until copas.finished() == true
if aggr == false then
   T:done()
end

----------------------------------------------------------------------
-- simple interface 
if aggr == false then
   T:start("simple interface - request_async - no handler")
end
local function task1(instance)
   dprint("task1-inst%d started", instance)
   local b, c, h = http_digest.request(url, true)
   dprint("task1-inst%d: body=%s status=%d header=%s", instance, b, c, pretty.write(h,""))
   T:eq( c, 200 )
   T:eq( json_decode(b), {authenticated = true, user = "user"} )
end

for i = 1, N do
   copas.addthread(task1, i)
end

if aggr == false then
   repeat
      copas.step()
   until copas.finished() == true
   T:done()
end


----------------------------------------------------------------------
-- simple interface 
if aggr == false then
   T:start("generic interface - request_async - no handler")
end
local function task2(instance)
   dprint("task2-inst%d started", instance)
   local b1 = {}
   local b, c, h = http_digest.request {
      url = url,
      sink = ltn12.sink.table(b1),
      handler = true,
   }
   dprint("task2-inst%d: body=%s status=%d header=%s", instance, b, c, pretty.write(h,""))
   T:eq( c, 200 )
   T:eq( json_decode(table.concat(b1)), {authenticated = true, user = "user"} )
end

for i = 1, N do
   copas.addthread(task2, i)
end

repeat
   copas.step()
until copas.finished() == true

T:done()
