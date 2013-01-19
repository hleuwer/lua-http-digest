# http-digest

## Presentation

Small implementation of HTTP Digest Authentication (client-side) in Lua
that mimics the API of LuaSocket.

Only supports auth/MD5, no reuse of client nonce, pull requests welcome.

## Dependencies

- luasocket
- md5

Tests require [cwtest](https://github.com/catwell/cwtest), a JSON parser
and the availability of [httpbin.org](http://httpbin.org).

## Usage

See [LuaSocket](http://w3.impa.br/~diego/software/luasocket/http.html)'s
`http.request`. Credentials must be contained in the URL. Both the simple and
generic interface are supported. Here is an example with the simple interface:

```lua
local http_digest = require "http-digest"
local url = "http://user:passwd@httpbin.org/digest-auth/auth/user/passwd"
local b,c,h = http_digest.request(url)
```

See the tests for more.

## Copyright

Copyright (c) 2012-2013 Moodstocks SAS
