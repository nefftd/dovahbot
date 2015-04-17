

-- util.lua: Shared utility functions


-- Namespace
local util = {}


-- Error, type checking
do
  local errfmt = "bad argument #%s to '%s' (%s expected, got %s)"
  
  local function checktypelist(t,a1,...)
    if a1 ~= nil then
      return t == a1 or checktypelist(t,...)
    end
  end
  
  function util.argcheck(val,argn,...)
    if checktypelist(type(val),...) then return end
    local fname = debug.getinfo(2,'n').name or '?'
    local types = table.concat({util.tostringall(...)},'/')
    argn = tonumber(argn) or '?'
    error(errfmt:format(argn,fname,types,type(val)),3)
  end
end


-- String functions
do
  local function tsa(n,a,...)
    if n > 0 then
      return tostring(a),tsa(n-1,...)
    end
  end
  
  function util.tostringall(...)
    return tsa(select('#',...),...)
  end
end


return util
