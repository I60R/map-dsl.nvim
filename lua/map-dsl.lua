--- Provides a nice DSL over which-key.nvim plugin, for example:
---
--- ```lua
--- (map "Comma is a leader!")
---   [','] = { '<Leader>', remap = false }
--- map:register { modes = 'nvo' }
--- ```
---
local Map = {}


-- Next enables `map ['key'] = { .. }` syntax that could be
-- called multiple times with the same key e.g. to add keymap
-- in different modes. The same wasn't possible to achieve by
-- regular lua tables because they can't store duplicate keys.
-- Mappings aren't registered yet but only temporarily stored
-- in the table until `map:register {}` is called
Map.__newindex = function(self, key, mapping_arguments)
    key = tostring(key)

    if type(mapping_arguments) ~= 'table' then
        -- It can be function or a string
        mapping_arguments = {
            mapping_arguments,
        }
    end

    if self.description ~= nil then
        mapping_arguments[2] = self.description
        self.description = nil
    end

    local key_arguments_tuple = {
        [key] = mapping_arguments,
    }

    local unique_id = #self + 1
    rawset(self, unique_id, key_arguments_tuple)
end

-- Next enables moving mapping description out of arguments
-- table e.g. `(map "x to y").x = { "y", remap = false }`
Map.__call = function(self, description)
    rawset(self, 'description', tostring(description))
    return _G.map
end

-- Next enables concatenation of mapping description without
-- any disambiguation e.g. `(map '[' .. x .. ']') [x] = ...`
Map.__concat = function(self, more_description)
    local pre = self.description or ''
    rawset(self, 'description', pre .. tostring(more_description))
    return _G.map
end


--- Next enables `split` and `register` methods on keymaps
--- table that allows to batch-operate on its contents.
--- Also provides Ctrl, Alt, Shift modifier keymaps that could
--- be used instead of <C-..>, <M-..>, <S-..>
local MapIndex = {}
Map.__index = MapIndex

-- Helper to map ctrl, atl, shift and their permutations, for example:
--
-- ```lua
-- (map "description")
--     .ctrl.alt ['x'] = { ... }
-- ```
--
local function map_with_modifiers(modifiers_list, next_possible_modifiers_list)
    local MapModifier = {}

    MapModifier.__index = next_possible_modifiers_list
    MapModifier.__newindex = function(_, key, mapping_arguments)
        key = tostring(key)

        if type(mapping_arguments) ~= 'table' then
            -- It can be function or a string
            mapping_arguments = {
                mapping_arguments,
            }
        end

        if mapping_arguments.mod ~= nil then
            for i, modifier in ipairs(modifiers_list) do
                mapping_arguments.mod[#mapping_arguments.mod + i] = modifier
            end
        else
            mapping_arguments.mod = modifiers_list
        end

        _G.map[key] = mapping_arguments
    end

    return setmetatable({}, MapModifier)
end


-- Enables `map.leader` modifier which could be extended
-- as `map.leader.ctrl`, `map.leader.ctrl.alt`, `map.leader.ctrl.shift`
-- and `map.leader.ctrl.alt.shift`
MapIndex.leader = map_with_modifiers({ "leader" }, {
    -- `map.leader.ctrl.alt` extension
    ctrl = map_with_modifiers({ "leader", "ctrl" }, {
        -- `map.leader.ctrl.alt` extension
        alt = map_with_modifiers({ "leader", "ctrl", "alt" }, {
            -- `map.leader.ctrl.alt.shift` extension
            shift = map_with_modifiers { "leader", "ctrl", "alt", "shift" },
        }),
        -- `map.leader.ctrl.shift` extension
        shift = map_with_modifiers { "leader", "ctrl", "shift" },
    }),
    -- `map.leader.alt` extension
    alt = map_with_modifiers { "leader", "alt" },
    -- `map.leader.shift` extension
    shift = map_with_modifiers { "leader", "shift" },
})


-- Enables `map.ctrl` modifier which could be extended
-- as `map.ctrl.alt`, `map.ctrl.shift` and `map.ctrl.alt.shift`
MapIndex.ctrl = map_with_modifiers({ "ctrl" }, {
    -- `map.ctrl.alt` extension
    alt = map_with_modifiers({ "ctrl", "alt" }, {
        -- `map.ctrl.alt.shift` extension
        shift = map_with_modifiers { "ctrl", "alt", "shift" },
    }),
    -- `map.ctrl.shift` extension
    shift = map_with_modifiers { "ctrl", "shift" },
})

-- Enables `map.alt` modifier which could be extended
-- as `map.alt.shift` only
MapIndex.alt = map_with_modifiers({ "alt" }, {
    -- `map.alt.shift` extension
    shift = map_with_modifiers { "alt", "shift" },
})

-- Enables `map.shift` modifier which cannot be extended,
-- use `map.ctrl` and `map.alt` instead
MapIndex.shift = map_with_modifiers { "shift" }


-- Common function for `MapIndex.split` and `MapIndex.register`
local function override_arguments(key_arguments_tuple, extra_arguments, for_each_hook)
    local key, mapping_arguments = next(key_arguments_tuple)

    for arg, value in pairs(extra_arguments) do repeat
            -- append extra modes instead of overriding them
            if arg == "modes" and mapping_arguments.modes then
                mapping_arguments.modes = mapping_arguments.modes .. value
                break
            end

            -- override arguments otherwise
            mapping_arguments[arg] = value
        until true
    end

    -- call hook that allows to modify the key
    if for_each_hook ~= nil then
        for_each_hook(key, mapping_arguments)
    end
end


-- This method thematically groups keymappings that currently
-- are in the table but not belongs to another group yet, and
-- allows to batch-modify them. This could be used to avoid
-- repeating the same arguments before each mapping e.g. `mode`.
MapIndex.split = function(self, extra_arguments)
    -- retain the function that would be called with each
    -- keymap and allows to modify them in this way
    local for_each_hook = extra_arguments.each
    extra_arguments.each = nil

    -- iterate from the end
    for rev_id = #self, 1, -1 do
        local key_arguments_tuple_from_end = self[rev_id]

        -- stop if another group was ended here
        if key_arguments_tuple_from_end == "GROUP-DELIMITER" then
            break
        end

        if extra_arguments and next(extra_arguments) ~= nil then
            -- modify keymapping arguments
            override_arguments(
                key_arguments_tuple_from_end,
                extra_arguments,
                for_each_hook
            )
        end
    end

    -- set delimiter so anoter `map:split {}` call wouldn't
    -- iterate over these options
    rawset(self, #self + 1, "GROUP-DELIMITER")
end

-- This method registers all keymappings that currently are
-- in the table including grouped ones and removes all them
-- from the table. It also allows to batch-modify mappings
-- that currently are in the table but not belongs to any
-- group, thus, allows to avoid extra `map:split {}` call.
MapIndex.register = function(self, extra_arguments)
    -- retain the function that would be called with each
    -- keymap and allows to modify them in this way
    local for_each_hook = extra_arguments.each;
    extra_arguments.each = nil

    -- iterate from beginning
    for id, key_arguments_tuple in ipairs(self) do repeat
            -- instantly remove the element
            self[id] = nil

            -- skip through group delimiters
            if key_arguments_tuple == "GROUP-DELIMITER" then
                break
            end

            -- override arguments if extra provided
            if extra_arguments and next(extra_arguments) ~= nil then
                override_arguments(
                    key_arguments_tuple,
                    extra_arguments,
                    for_each_hook
                )
            end

            -- proceed to registering the mapping
            local key, mapping_arguments = next(key_arguments_tuple)
            -- update rhs if `type` and/or `plug` are provided
            local rhs = mapping_arguments[1]

            -- process `as = 'cmd'` and `as = 'lua'`
            if type(rhs) == "string" then
                if mapping_arguments[2] ~= nil then
                    if mapping_arguments.as == 'cmd' then
                        rhs = '<Cmd>' .. rhs .. '<CR>'
                    elseif mapping_arguments.as == 'lua' then
                        rhs = '<Cmd>lua ' .. rhs .. '<CR>'
                    elseif mapping_arguments.as == 'call' then
                        rhs = '<Cmd>call ' .. rhs .. '<CR>'
                    end
                else
                    mapping_arguments[2] = rhs
                    rhs = ''
                end

                -- process 'plug' flag
                if mapping_arguments.plug ~= nil then
                    rhs = '<Plug>(' .. mapping_arguments.plug .. ')' .. rhs
                end

                mapping_arguments[1] = rhs
            end

            -- replace `remap` with `noremap`
            if mapping_arguments.remap ~= nil then
                mapping_arguments.noremap = not mapping_arguments.remap
            end

            -- replace `modes` with `mode`
            mapping_arguments.mode = mapping_arguments.modes

            -- process modifier keys if they're present
            if mapping_arguments.mod ~= nil then
                local modifiers = {}
                for _, modifier in pairs(mapping_arguments.mod) do
                    modifiers[modifier] = true
                end
                if modifiers.ctrl and modifiers.alt and modifiers.shift then
                    key = '<C-M-S-' .. key .. '>'
                elseif modifiers.ctrl and modifiers.alt then
                    key = '<C-M-' .. key .. '>'
                elseif modifiers.ctrl and modifiers.shift then
                    key = '<C-S-' .. key .. '>'
                elseif modifiers.alt and modifiers.shift then
                    key = '<M-S-' .. key .. '>'
                elseif modifiers.ctrl then
                    key = '<C-' .. key .. '>'
                elseif modifiers.alt then
                    key = '<M-' .. key .. '>'
                elseif modifiers.shift then
                    key = '<S-' .. key .. '>'
                end
                if modifiers.leader then
                    key = "<Leader>" .. key
                end
            end

            -- remove entries which which-key doesn't understand
            mapping_arguments.modes = nil
            mapping_arguments.mod = nil
            mapping_arguments.remap = nil
            mapping_arguments.plug = nil
            mapping_arguments.as = nil

            -- common functionality
            local function register_key(mapping_or_mode_mapping_arguments)
                -- call hook that allows to modify the key
                if for_each_hook ~= nil then
                    for_each_hook(key, mapping_or_mode_mapping_arguments)
                end

                -- map key in the current mode
                require('which-key').register { [key] = mapping_or_mode_mapping_arguments }
            end

            -- map key in multiple modes if more than one are specified
            if mapping_arguments.mode and #mapping_arguments.mode > 1 then
                for mode_letter in mapping_arguments.mode:gmatch '.' do
                    -- create a new keymapping for each mode because
                    -- which-key doesn't register them instantly and
                    -- doesn't create copies, so updating the same keymap
                    -- would update all registered in previous iterations
                    local mode_mapping_arguments = {}
                    -- copy mapping arguments
                    for arg, value in pairs(mapping_arguments) do
                        mode_mapping_arguments[arg] = value
                    end
                    -- swap modes with the current mode letter
                    mode_mapping_arguments.mode = mode_letter

                    register_key(mode_mapping_arguments)
                end
                break
            end

            register_key(mapping_arguments)
        until true
    end
end


_G.map = setmetatable({}, Map)
