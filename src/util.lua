function strict(tab)
    setmetatable(tab, {__index = function(t,i)
        error("attempt to index invalid key `"..i.."`")
    end})
end

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
                print(("-"):rep(depth)..i..": "..tostring(v))
            end
        end
    end
    if depth == 0 then print() end
end

function table.equal(table1, table2)
   local avoid_loops = {}
   local function recurse(t1, t2)
      -- compare value types
      if type(t1) ~= type(t2) then return false end
      -- Base case: compare simple values
      if type(t1) ~= "table" then return t1 == t2 end
      -- Now, on to tables.
      -- First, let's avoid looping forever.
      if avoid_loops[t1] then return avoid_loops[t1] == t2 end
      avoid_loops[t1] = t2
      -- Copy keys from t2
      local t2keys = {}
      local t2tablekeys = {}
      for k, _ in pairs(t2) do
         if type(k) == "table" then table.insert(t2tablekeys, k) end
         t2keys[k] = true
      end
      -- Let's iterate keys from t1
      for k1, v1 in pairs(t1) do
         local v2 = t2[k1]
         if type(k1) == "table" then
            -- if key is a table, we need to find an equivalent one.
            local ok = false
            for i, tk in ipairs(t2tablekeys) do
               if table.equal(k1, tk) and recurse(v1, t2[tk]) then
                  table.remove(t2tablekeys, i)
                  t2keys[tk] = nil
                  ok = true
                  break
               end
            end
            if not ok then return false end
         else
            -- t1 has a key which t2 doesn't have, fail.
            if v2 == nil then return false end
            t2keys[k1] = nil
            if not recurse(v1, v2) then return false end
         end
      end
      -- if t2 has a key which t1 doesn't have, fail.
      if next(t2keys) then return false end
      return true
   end
   return recurse(table1, table2)
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
    if val == nil then
        if callback then callback() end
        error(name.." is nil")
    end
    if val.type == nil then
        if callback then callback() end
        error(name.." isn't "..ty..", has no type")
    end
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


