function table.print(tab, depth)
    if type(tab) ~= "table" then print(("-"):rep(depth)..tab) return end
    local depth = depth or 0
    for i,v in next,tab do
        if type(v) == "table" then
            print(("-"):rep(depth)..i)
            table.print(v, depth + 1)
        else
            print(("-"):rep(depth)..i..": "..v)
        end
    end
    if depth == 0 then print() end
end

function table.copy(val)
    if type(val) == "table" then
        local copy = {}
        for i,v in next,val do
            copy[i] = table.copy(v)
        end
        return copy
    else
        return val
    end
end

function enum(name)
    return function(tag, members)
        return function(...)
            local t = {type = name, tag = tag}
            for i,v in next,members do
                t[v] = select(i, ...)
            end
            return t
        end
    end
end


