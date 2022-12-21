# A neat DSL for creating keymappings in neovim


## Structure

```lua
;(map "Mapping description for which-key")
    ['Keys'] = 'OtherKey'

;(map "Modifiers also supported")
    .leader.ctrl.alt.shift['Keys'] = 'OtherKey'

;(map "Table on RHS support")
    ['Keys'] = { 'Command', remap = true, silent = true, as = 'cmd' }

;(map "Lua function on RHS (also could be used in table as above)")
    ['Keys'] = function() x() end

map:split { remap = false } -- modify all above mappings

;(map "Plug mappings")
    ['Keys'] = { plug = "argument" }

;(map "Lua expression")
    ['Keys'] = { "print('hello')", as = 'lua' }

;(map "Call expression")
    ['Keys'] = { "expand('<cword>')", as = 'call' }

map:split { silent = false } -- modify all mappings after previous split

;(map "Single mode")
    ['Keys'] = { "OtherKey", mode = 'n' }

;(map "Multiple modes")
    ['Keys'] = { "OtherKey", modes = 'niv' }

-- This call is mandatory, otherwise mappings wouldn't be registered
map:register {
    mode = 'x', -- you can also modify mappings as with split
    each = function(key, rhs) -- and even with function!
        rhs.silent = true
    end
}
```

## Examples of usage

```lua
;(map "Unmap space")
    ['<Space>'] = '<Nop>'
;(map "Space is the leader key!")
    ['<Space>'] = '<Leader>'

map:register { remap = true }
```

```lua
for n = 1, 9 do
    local function focus_nth_buffer() require('bufferline').go_to_buffer(n) end
    ;(map "Go to (" .. n .. ") buffer")
        .alt[n] = { focus_nth_buffer, remap = false, silent = true };
end

;(map "Pick a buffer")
    .alt['`'] = 'BufferLinePick'
;(map "Previous buffer")
    .alt['Left'] = 'BufferLineCyclePrev'
;(map "Next buffer")
    .alt['Right'] = 'BufferLineCycleNext'
;(map "Close buffer")
    .alt['q'] = 'b # | bd #'
;(map "Previous buffer")
    ['<F13>'] = 'BufferLineCyclePrev'
;(map "Next buffer")
    ['<F14>'] = 'BufferLineCycleNext'

map:register { as = 'cmd', modes = 'nicxsot' }
```

```lua
;(map "Accelerated j")
    ['j'] = { plug = 'accelerated_jk_j', modes = 'n' }
;(map "Accelerated k")
    ['k'] = { plug = 'accelerated_jk_k', modes = 'n' }

map:register {}
```

## Installation

Via [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
    'I60R/map-dsl.nvim',
    as = 'map',
    requires = 'folke/which-key.nvim',
    config = function()
        local map_dsl = require('map-dsl')
        local which_key = require('which-key')

        -- configure these plugins here
    end
}

use {
    'author/plugin',
    after = 'map', -- this is mandatory
    config = function()

        -- define keymappings here
    end
}

```

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'I60R/map-dsl.nvim',
    requires = 'folke/which-key.nvim',
    config = function()
        local map_dsl = require('map-dsl')
        local which_key = require('which-key')

        -- configure these plugins here
    end
},

{
    'author/plugin',
    dependencies = 'I60R/map-dsl.nvim', -- this is mandatory
    config = function()

        -- define keymappings here
    end
},

```



