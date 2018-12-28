function table.print(tab, depth)
    local depth = depth or 0
    if type(tab) ~= "table" then print(("-"):rep(depth)..tab) return end
    local is_class = tab.type and tab.tag
    if is_class then
        print(("-"):rep(depth)..tab.type.."."..tab.tag)
    end
    for i,v in next,tab do
        if type(v) == "table" then
            print(("-"):rep(depth)..i)
            table.print(v, depth + 1)
        else
            if is_class and i == "type" or i == "tag" then
                -- do nothing
            else
                print(("-"):rep(depth)..i..": "..v)
            end
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

function expect(cond,msg,level)
    if not cond then
        error(msg,level or 2)
    end
end

function expect_type(val, name, ty, callback)
    if val.type ~= ty then
        if callback then callback() end
        error(name.." isn't "..ty..", instead "..val.type)
    end
end

function delay(f,...)
    local k = {...}
    return function()
        f(unpack(k))
    end
end

function enum(name)
    expect(type(name) == "string", "enum name not string")
    return function(tag, members)
        local path = name.."."..tag
        expect(type(tag) == "string", "enum tag not string")
        expect(type(members) == "table", "enum members not table")
        return function(build)
            expect(type(build) == "table", "constructor list for "..path.." not table")
            local t = {type = name, tag = tag}
            for i,v in next,members do
                expect(build[v] ~= nil, "constructor of "..path.."."..v.." is nil",2)
                t[v] = build[v]
            end
            return t
        end
    end
end


