lovebug
=======

In-game console/debugging tool for LÖVE projects

Usage
-----

This library is non-invasive to the default LÖVE functions, so you'll have to call the module's load(), draw(), and keypressed() functions explicitly. The console is activated with '~', but this setting and many others can be edited in console.lua.

Example
-------

```lua
local console = require("lovebug.console")

function love.load()
  console.load()
  
  console.log("hey look, i'm logging to the console.")
end

function love.draw()
  console.draw()
end

function love.keypressed(key, unicode)
  console.keypressed(key, unicode)
end
```

License
=======
Copyright (c) 2013 Nicholas Campbell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
