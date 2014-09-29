--- Returns string representation of object obj
-- @return String representation of obj
function dir(obj,level)
    local s,t = '', type(obj)
    
    level = level or '  '

    if (t=='nil') or (t=='boolean') or (t=='number') or (t=='string') then
        s = tostring(obj)
        if t=='string' then
            s = '"' .. s .. '"'
        end
    elseif t=='function' then s='function'
    elseif t=='userdata' then s='userdata'
    elseif t=='thread' then s='thread'
    elseif t=='table' then
        s = '{'
        for k,v in pairs(obj) do
            local k_str = '"' .. tostring(k) .. '"'
            s = s .. k_str .. ': ' .. dir(v,level .. level) .. ', '
        end
        if #obj > 0 then
            s = string.sub(s, 1, -3)
        end
        s = s .. '}'
    end
    
    return s
end

return {dir=dir}
