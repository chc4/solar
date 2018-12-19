value = require "src/value"
types = require "src/types"
context = {}

function context.new()
    local obj = setmetatable({},
                    setmetatable({__index = context},value)
                )
    return obj
end

context.type = "context"

function context:add(val)
    local new = {}
    new.left = val
    new.right = self
    return new
end

function context:replace(axis, val)
    if axis == 1 then
        return val
    elseif axis % 2 == 0 then
        local new = context.new()
        new.left = table.copy(self.left):replace(math.floor(axis / 2), val)
        new.right = context.right
        return new
    elseif axis % 2 == 1 then
        local new = context.new()
        new.left = context.left
        new.right = table.copy(self.right):replace(math.floor(axis / 2), val)
        return new
    end
end

function context:fetch(axis)
    if axis == 1 then
        return val
    elseif axis % 2 == 0 then
        return context.left:fetch(math.floor(axis / 2))
    elseif axis % 2 == 1 then
        return context.right:fetch(math.floor(axis / 2))
    end
end

return context
