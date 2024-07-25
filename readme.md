This repository contains a Lua module for the evaluation of textual templates,
such as `hello $(whom)`. Possible uses of template engines include code or html
generation.

Using a special syntax, templates can refer to _any valid Lua expression_ which
must be evaluatable _in the given environment_.
Arbitrary Lua code can also be intertwined with the text.

Below is a representative example (more simple examples in
`src/sample/sample.lua`).

```Lua
local engine = require('template-text')

local tpl = [[
Hi! This is a text template!
It can reference any symbol which is defined in the environment (i.e. a table)
given to the evaluation function:

Hello $(name) for $(many(5)) times!

Actual Lua code can be used in the template, starting the line with a '@':
@ for k,v in pairs( aTable ) do
key: $(k)    value: $(v)
@ end
]]

local dummyF = function(i) return i*3 end
local dummyT = {"bear", "wolf", "shark", "monkey"}

-- Error checking omitted for brevity

local ok, parsed = engine.parse(tpl, {},
  { name   = "Marco",
    many   = dummyF,
    aTable = dummyT}
)
local text
ok, text = parsed.evaluate()
print(text)
```

Running this sample with
```
cd src/sample
lua fromreadme.lua
```
should produce the following output:
```
Hi! This is a text template!
It can reference any symbol which is defined in the environment (i.e. a table)
given to the evaluation function:

Hello Marco for 15 times!

Actual Lua code can be used in the template, starting the line with a '@':
key: 1    value: bear
key: 2    value: wolf
key: 3    value: shark
key: 4    value: monkey

```

# Installing

## Via LuaRocks

If you can use [LuaRocks](https://luarocks.org/), then this command will install
the package from the public repository:

```
luarocks install --local template-text
```

Beware that the version of LuaRocks from the package-manger of your OS might be
old or default to an old Lua version.

Alternatively, you can install from a local clone of the source repository:

```sh
git clone https://github.com/mfrigerio17/lua-template-engine.git
cd lua-template-engine/
luarocks --local make           # installs the module locally
eval `luarocks path`            # need this everytime, with --local
lua src/sample/fromreadme.lua   # try a sample
```

Avoid the `--local` switch to install the module in a system-wide Lua directory.

## Manual installation
You may simply copy the source file `template-text.lua` in a system-wide Lua
directory (adapt the folder to your system and Lua version).

```sh
git clone https://github.com/mfrigerio17/lua-template-engine.git
cd lua-template-engine/

# This one will need root privileges
mkdir -p /usr/local/share/lua/5.2/ && cp src/template-text.lua /usr/local/share/lua/5.2/

# Run a sample
lua src/sample/fromreadme.lua
```

# Dependencies

The template engine does not depend on any other module. Lua > 5.1 is required.

# API docs

The module's API documentation can be generated from the comments in the source
code, using [LDoc](https://stevedonovan.github.io/ldoc/):

```
ldoc -c doc/config.ld src/
```

# Authorship

By Marco Frigerio, heavily based on the code available in the
[Lua-users-wiki](http://lua-users.org/wiki/SlightlyLessSimpleLuaPreprocessor)

Copyright © 2020-2024 Marco Frigerio  
All rights reserved.

Released under a permissive BSD license. See the `LICENSE` file for details.
