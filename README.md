# A neat DSL for creating keymappings in neovim

Examples of usage:

```lua
(map "Unmap space")
    ['<Space>'] = '<Nop>'
(map "Space is the leader key!")
    ['<Space>'] = '<Leader>'

map:register { remap = true }
```

```lua
for n = 1, 9 do
    local function focus_nth_buffer() require('bufferline').go_to_buffer(n) end
    (map "Go to (" .. n .. ") buffer")
        .alt[n] = { focus_nth_buffer, remap = false, silent = true };
end

(map "Pick a buffer")
    .alt['`'] = 'BufferLinePick'
(map "Previous buffer")
    .alt['Left'] = 'BufferLineCyclePrev'
(map "Next buffer")
    .alt['Right'] = 'BufferLineCycleNext'
(map "Close buffer")
    .alt['q'] = 'b # | bd #'
(map "Previous buffer")
    ['<F13>'] = 'BufferLineCyclePrev'
(map "Next buffer")
    ['<F14>'] = 'BufferLineCycleNext'

map:register { as = 'cmd', modes = 'nicxsot' }
```

```lua
(map "Accelerated j")
    ['j'] = { plug = 'accelerated_jk_j', modes = 'n' }
(map "Accelerated k")
    ['k'] = { plug = 'accelerated_jk_k', modes = 'n' }

map:register {}
```

## Installation

Via [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
-- This must be at the top of your plugin declarations
use {
    'I60R/map-dsl.nvim',
    requires = 'folke/which-key.nvim',
    config = function()
        local map_dsl = require('map-dsl')
        local which_key = require('which-key')
        -- configure these plugins here
    end
}

-- This must come next after map-dsl declaration
_G.use = function(spec)
    if type(spec.after) == 'string' then
        spec.after = { spec.after, }
    end
    spec.after[#spec.after+1] = "map-dsl.nvim"
end

-- Put the rest of your plugins here.
-- They'll use redefined `use` function
-- which loads map-dsl before each plugin.
```


