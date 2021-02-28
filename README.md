# http-digest

## Presentation

Small implementation of HTTP Digest Authentication (client-side) in Lua
that mimics the API of LuaSocket.

Only supports auth/MD5, no reuse of client nonce, pull requests welcome.

## Dependencies

- luasocket
- md5
- copas (only for asynchronous operation)

Tests require [cwtest](https://github.com/catwell/cwtest), a JSON parser
and the availability of [httpbin.org](http://httpbin.org).

## Usage

See [LuaSocket](http://w3.impa.br/~diego/software/luasocket/http.html)'s
`http.request`. Credentials must be contained in the URL. Both the simple and
generic interface are supported. Asynchronous calls are supported only with
the simple interface.

Here is an example with the simple interface. The request is blocks and waits for the response:

```lua
local http_digest = require "http-digest"
local url = "http://user:passwd@httpbin.org/digest-auth/auth/user/passwd"
local b, c, h = http_digest.request(url)
```

Here is another example using asynchronous requests provided by copas with a user supplied handler function. The handler receives the body of the response, the HTTP status code and the response header. This form is intended to be used in cases, hwere http-digest.lua is not used within another module providing a response header like luasoap.lua.

```lua
local http_digest = require "http-digest"
local url = "http://httpbin.org/digest-auth/auth/user/passwd"
local b, c, h = http_digest.request{
  url = url,
  user = USER,
  password = PASSWORD,
  handler = function(b, c, h)
    print("Request returned with status code " .. c)
  end
)
```

This third example also uses asynchronoous requests provided by copas. No 
handler funciton is supplied to the request. A boolean value for handler indicates that the request shall be asynchronous.

```lua
local http_digest = require "http-digest"
local url = "http://httpbin.org/digest-auth/auth/user/passwd"
local b, c, h = http_digest.request{
  url = url,
  user = USER,
  password = PASSWORD,
  handler = true 
)
```

Finally the same use case but with the simple interface. A second boolean parameter instructs http-digest to operate asynchronously.

```lua
local http_digest = require "http-digest"
local url = "http://user:passwd@httpbin.org/digest-auth/auth/user/passwd"
local b, c, h = http_digest.request(url, true)
```

See the tests for more.

## Note

If you get this error when running the tests, update LuaSocket:

    variable 'PROXY' is not declared

You may need to use the SCM version to run them (see
[this issue](https://github.com/diegonehab/luasocket/issues/110)).

This only impacts the tests, the code itself works with older versions as well.

## Copyright

- Copyright (c) 2012-2013 Moodstocks SAS
- Copyright (c) 2014-2018 Pierre Chapuis
