local Luaoop = {}

local lua5_1 = (string.find(_VERSION, "5.1") ~= nil)

-- CLASS MODULE

local class = {}

local classes = {}

-- __index used for class inheritance (no optimization, safe access)
local function class_index(t,k)
  local bases = getmetatable(t).bases
  -- find key in table properties
  for l,v in pairs(bases) do
    local p = v[k]
    if type(p) == "function" then
      return p
    end
  end
end 

-- force an instance to have a custom mtable (by default they share the same table for optimization)
-- mtable: current instance mtable
-- o: instance
-- return custom mtable
local function force_custom_mtable(mtable, o)
  if not mtable.custom then
    -- copy mtable
    local new_mtable = {}
    for k,v in pairs(mtable) do
      new_mtable[k] = v
    end

    -- flag custom
    new_mtable.custom = true
    setmetatable(o, new_mtable)

    mtable = new_mtable
  end

  return mtable
end

-- private access name optimization
local private_dict = {}

-- return private context or nil
local function class_pow_instance(c, o)
  local cmtable = getmetatable(c)

  if o then
    local omtable = getmetatable(o)
    if omtable and omtable.instance then
      omtable = force_custom_mtable(omtable, o) -- private access requires custom properties

      -- get/gen key
      local key = private_dict[cmtable.classname]
      if not key then
        key = cmtable.classname.."_p"
        private_dict[cmtable.classname] = key
      end

      local private = omtable[key]
      if not private then
        private = {}
        omtable[key] = private
      end

      return private
    end
  end
end

-- create a new class with the passed identifier (following the Lua name notation, no special chars except underscore) and base classes (multiple inheritance possible)
-- return new class
function class.new(name, ...)
  if type(name) == "string" and string.len(name) > 0 then
    local c = {}
    local bases = {...}

    -- replace safe access
    for k,v in pairs(bases) do
      local c, mt = class.unsafe(v)
      if c and mt.fclass then -- is safe access with class functionalities
        bases[k] = c 
      end
    end

    local types = { [name] = true } -- add self type

    -- check inheritance validity and build types map
    for k,v in pairs(bases) do
      local mtable = getmetatable(v)

      if not mtable or (not mtable.classname and not mtable.bases) then -- if not a class
        error("invalid class definition "..name)
      end

      -- add types
      for t,_ in pairs(mtable.types) do
        types[t] = true
      end
    end

    if #bases > 1 then -- multiple inheritance, proxy
      setmetatable(c,{ __index = class_index, bases = bases, types = types })
      return class.new(name, c) -- then single inheritance of the proxy
    else -- single inheritance
      setmetatable(c, { __index = class_index, bases = bases, types = types, class = true, classname = name, __call = class.instanciate, __pow = class_pow_instance})

      if not classes[name] then
        classes[name] = c -- reference class
      else
        error("redefinition of class "..name)
      end

      return c
    end
  end
end

-- return the class definition for the specified class name (nil if not found)
-- it is a raw access, any method can be modified/added/removed
function class.definition(name)
  return classes[name]
end

-- same as class.definition but returning a safe access class
function class.safedef(name)
  return class.safeaccess(class.definition(name), true)
end

-- return a new table giving access to the passed table properties (prevents adding/removing/modifying properties)
-- (deep, recursive safe access on subtables)
-- useful to protect global class data from modifications (only if getmetatable is not allowed)
-- works also to get a safe class definition for inheritance and instantiation
--
-- fclass: if passed/true, will preserve class table functionalities
function class.safeaccess(t, fclass)
  if t then
    local mtable = getmetatable(t) or {}
    if not mtable.safe_access then -- check if not already a safeaccess
      local _t = {}

      local mt = {
        safe_access = t, -- define special property to recognize safe access, save original table
        __index = function(_t, k)
          local v = t[k]
          if type(v) == "table" then -- create subtable safe access
            v = class.safeaccess(v, fclass)
            rawset(_t,k,v) -- save access
          end
          
          return v -- return regular value
        end
        , __newindex = function(t,k,v) end -- prevents methods obfuscation with newindex
      }

      -- flags
      if fclass then 
        mt.__call = mtable.__call 
        mt.fclass = true -- flag with class functionalities
      end

      return setmetatable(_t, mt)
    else
      return t
    end
  end
end

-- return the original table from a safe access table, or nil if not a safe access
-- return also the safe access metatable as second return values
function class.unsafe(safe_access)
  local mtable = getmetatable(safe_access)
  if mtable and mtable.safe_access then
    return mtable.safe_access, mtable
  end
end

-- return classname or nil if not a class or instance of class
function class.name(t)
  local c, mt = class.unsafe(t)
  if c then t = c end -- is safe access, replace with class

  if t ~= nil then
    local mtable = getmetatable(t)
    if mtable ~= nil then
      return mtable.classname
    end
  end
end

-- return the defined classname or the lua type for an instance or class
function class.type(t)
  local name = class.name(t)
  if name == nil then
    name = type(t)
  end

  return name
end

-- check if an instance/class is/inherits from a specific classname
function class.is(t, name)
  local c, mt = class.unsafe(t)
  if c then t = c end -- is safe access, replace with class

  if t ~= nil then
    local mtable = getmetatable(t)
    if mtable ~= nil then
      local types = mtable.types
      if types ~= nil then return types[name] ~= nil end
    end
  end

  return false
end

-- alias for inherits
class.instanceof = class.is

-- return instance/class types map (type => true)
function class.types(t)
  local c, mt = class.unsafe(t)
  if c then t = c end -- is safe access, replace with class

  if t ~= nil then
    local mtable = getmetatable(t)
    if mtable ~= nil and mtable.types ~= nil then
      -- return a copy of the types map
      local types = {}
      for k,v in pairs(mtable.types) do
        types[k] = v
      end

      return types
    end
  end
end

-- optimize special method name resolution
local op_dict = {}

-- get operator from instance/class, rhs_class can be nil for unary operators
function class.getop(lhs_class, name, rhs_class, no_error)
  local f = nil

  local mtable = getmetatable(lhs_class)
  if mtable and (mtable.instance or mtable.classname) then -- check if class or instance
    local rtype = class.type(rhs_class)

    -- optimization using op_dict
    local dict = op_dict[name]
    if not dict then
      dict = {}
      op_dict[name] = dict
    end

    -- method name
    local fname = dict[rtype]
    if not fname then -- generate fname
      if rhs_class then
        fname = "__"..name.."_"..rtype
      else
        fname = "__"..name
      end

      dict[rtype] = fname
    end

    f = lhs_class[fname]
  end

  if f then
    return f
  elseif not no_error then
    error("operator <"..class.type(lhs_class).."> ["..name.."] <"..class.type(rhs_class).."> undefined")
  end
end

local getop = class.getop

-- proxy lua operators
local function op_tostring(lhs)
  local f = getop(lhs, "tostring", nil, true)
  if f then
    return f(lhs)
  else
    return "class<"..class.name(lhs)..">: "..class.instanceid(lhs)
  end
end

local function op_concat(lhs,rhs)
  local f = getop(lhs, "concat", rhs, true)
  if f then 
    return f(lhs,rhs) 
  end

  f = getop(rhs, "concat", lhs)
  if f then 
    return f(rhs,lhs,true) 
  end
end

local function op_unm(lhs)
  local f = getop(lhs, "unm", nil)
  if f then return f(lhs) end
end

local function op_call(lhs, ...)
  local f = getop(lhs, "call", nil)
  if f then return f(lhs, ...) end
end

local function op_add(lhs,rhs)
  local f = getop(lhs, "add", rhs, true)
  if f then 
    return f(lhs,rhs) 
  end

  f = getop(rhs, "add", lhs)
  if f then 
    return f(rhs,lhs) 
  end
end

local function op_sub(lhs,rhs) -- also deduced as lhs+(-rhs)
  local f = getop(lhs, "sub", rhs, true)
  if f then 
    return f(lhs,rhs)
  end

  f = getop(lhs, "add", rhs)
  if f then
    return f(lhs, -rhs)
  end
end

local function op_mul(lhs,rhs)
  local f = getop(lhs, "mul", rhs, true)
  if f then 
    return f(lhs,rhs) 
  end

  f = getop(rhs, "mul", lhs)
  if f then 
    return f(rhs,lhs) 
  end
end

local function op_div(lhs,rhs)
  local f = getop(lhs, "div", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_mod(lhs,rhs)
  local f = getop(lhs, "mod", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_pow(lhs,rhs)
  local f = getop(lhs, "pow", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_eq(lhs,rhs)
  local f = getop(lhs, "eq", rhs, true)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_lt(lhs,rhs)
  local f = getop(lhs, "lt", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_le(lhs,rhs)
  local f = getop(lhs, "le", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

-- __index used for instance inheritance (optimization)
local function instance_index(t,k)
  local mtable = getmetatable(t)
  local p = mtable.class[k]

  t[k] = p -- cache member
  return p
end

-- instantiated type mtables, optimize instanciation (no custom mtable properties)
local insmt_dict = {}

-- get the class metatable applied to the instances
-- useful to apply class behaviour to a custom table
-- (not a safe access)
function class.meta(_class)
  if _class then
    local cmtable = getmetatable(_class)

    if cmtable and cmtable.class and cmtable.classname then -- if a class
      local mtable = insmt_dict[cmtable.classname]
      if not mtable then
        -- build generic instance mtable
        local index = setmetatable({}, { __index = instance_index, class = _class }) -- instance type index 

        mtable = {
          __index = index, 
          instance = true,
          classname = cmtable.classname,
          types = cmtable.types,

          -- add operators metamethods
          __call = op_call,
          __unm = op_unm,
          __add = op_add,
          __sub = op_sub,
          __mul = op_mul,
          __div = op_div,
          __pow = op_pow,
          __mod = op_mod,
          __eq = op_eq,
          __le = op_le,
          __lt = op_lt,
          __tostring = op_tostring,
          __concat = op_concat
        }

        insmt_dict[cmtable.classname] = mtable
      end

      return mtable
    end
  end
end

-- create object with a specific class and constructor arguments 
function class.instanciate(_class, ...)
  local c, mt = class.unsafe(_class)
  if c and mt.fclass then _class = c end -- is safe access with class functionalities, replace with class

  local mtable = class.meta(_class) -- get class meta

  if mtable then -- valid meta
    -- create instance
    local o = setmetatable({},mtable) 

    local constructor = o.__construct
    local destructor = o.__destruct

    if destructor then
      mtable = force_custom_mtable(mtable, o) -- gc requires custom properties

      local gc = function()
        destructor(o)
      end

      if lua5_1 then -- Lua 5.1
        local proxy = newproxy(true)
        getmetatable(proxy).__gc = gc
        mtable.proxy = proxy
      else
        mtable.proxy = setmetatable({}, { __gc = gc })
      end
    end

    -- construct
    if constructor then constructor(o, ...) end
    return o
  end
end

-- propagate changes for the specified string instance types
-- this function is not about class propagation (since class properties are not cached), but instance type propagation
-- you need to call it for every instantiated types that should inherit the new modifications
-- ...: list of types (strings) that will be updated
function class.propagate(...)
  for k,v in pairs({...}) do
    local mtable = insmt_dict[v]
    if mtable then
      -- remove instantiated type cached properties
      local index = mtable.__index
      for k,v in pairs(index) do
        index[k] = nil
      end
    else
      error(v.." is not an instantiated type")
    end
  end
end

-- return address number from table (tostring hack, return nil on failure)
local function table_addr(t)
  local hex = string.match(tostring(t), ".*(0x%x+).*")
  if hex then return tonumber(hex) end
end

local addr_counter = 0 -- addr counter in replacement of table_addr

-- return unique instance id (or nil if not an instance)
-- works by using tostring(table) address hack or using a counter instead on failure
function class.instanceid(o)
  if o then
    local mtable = getmetatable(o)
    mtable = force_custom_mtable(mtable, o) -- instanceid requires custom properties

    if mtable.id then -- return existing id
      return mtable.id
    elseif mtable.instance then  -- generate id
      -- remove tostring proxy
      mtable.__tostring = nil
      -- generate addr
      mtable.id = table_addr(o)
      -- reset tostring proxy
      mtable.__tostring = op_tostring

      if not mtable.id then
        mtable.id = addr_counter
        addr_counter = addr_counter+1
      end

      return mtable.id
    end
  end
end

-- SHORTCUTS
setmetatable(class, { __call = function(t, name, ...) 
  return class.new(name, ...)
end})

-- NAMESPACES
Luaoop.class = class



-- LuaJIT CCLASS MODULE

if jit then

local ffi = require("ffi")
local C = ffi.C
local cclass = {}

-- change the symbols dict for the next following cclass (ffi.C by default)
function cclass.symbols(symbols)
  C = symbols
end

local cintptr_t = ffi.typeof("intptr_t")
local function f_id(self)
  return tonumber(ffi.cast(cintptr_t, self))
end

-- NOTE: operator redundant code until better way

-- optimize special method name resolution
local op_dict = {}

-- get operator from instance lhs, rhs can be nil for unary operators
local function getop(lhs, name, rhs, no_error)
  local f = nil

  local rtype = nil
  if type(rhs) == "cdata" then
    rtype = rhs:__type()
  else
    rtype = type(rhs)
  end

  local ltype = nil
  if type(lhs) == "cdata" then
    ltype = lhs:__type()
  else
    ltype = type(lhs)
  end

  -- optimization using op_dict
  local dict = op_dict[name]
  if not dict then
    dict = {}
    op_dict[name] = dict
  end

  -- method name
  local fname = dict[rtype]
  if not fname then -- generate fname
    if rhs then
      fname = "__"..name.."_"..rtype
    else
      fname = "__"..name
    end

    dict[rtype] = fname
  end

  if type(lhs) == "cdata" then
    f = lhs:__get(fname)
  end

  if f then
    return f
  elseif not no_error then
    error("operator <"..ltype.."> ["..name.."] <"..rtype.."> undefined")
  end
end

-- proxy lua operators
local function op_tostring(lhs)
  local f = getop(lhs, "tostring", nil, true)
  if f then
    return f(lhs)
  else
    return "cclass<"..lhs:__type()..">: "..lhs:__id()
  end
end

local function op_concat(lhs,rhs)
  local f = getop(lhs, "concat", rhs, true)
  if f then 
    return f(lhs,rhs) 
  end

  f = getop(rhs, "concat", lhs)
  if f then 
    return f(rhs,lhs,true) 
  end
end

local function op_unm(lhs)
  local f = getop(lhs, "unm", nil)
  if f then return f(lhs) end
end

local function op_call(lhs, ...)
  local f = getop(lhs, "call", nil)
  if f then return f(lhs, ...) end
end

local function op_add(lhs,rhs)
  local f = getop(lhs, "add", rhs, true)
  if f then 
    return f(lhs,rhs) 
  end

  f = getop(rhs, "add", lhs)
  if f then 
    return f(rhs,lhs) 
  end
end

local function op_sub(lhs,rhs) -- also deduced as lhs+(-rhs)
  local f = getop(lhs, "sub", rhs, true)
  if f then 
    return f(lhs,rhs)
  end

  f = getop(lhs, "add", rhs)
  if f then
    return f(lhs, -rhs)
  end
end

local function op_mul(lhs,rhs)
  local f = getop(lhs, "mul", rhs, true)
  if f then 
    return f(lhs,rhs) 
  end

  f = getop(rhs, "mul", lhs)
  if f then 
    return f(rhs,lhs) 
  end
end

local function op_div(lhs,rhs)
  local f = getop(lhs, "div", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_mod(lhs,rhs)
  local f = getop(lhs, "mod", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_pow(lhs,rhs)
  local f = getop(lhs, "pow", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_eq(lhs,rhs)
  local f = getop(lhs, "eq", rhs, true)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_lt(lhs,rhs)
  local f = getop(lhs, "lt", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

local function op_le(lhs,rhs)
  local f = getop(lhs, "le", rhs)
  if f then 
    return f(lhs,rhs) 
  end
end

-- create C-like FFI class
-- name: name of the class, used to define the cdata type and the functions prefix
-- statics: static functions exposed to the class object, special functions are exposed by default
-- methods: methods exposed to the instances, special methods are overridden
-- ...: inherited bases cclass 
function cclass.new(name, statics, methods, ...)
  local ctype = ffi.typeof(name)
  local pctype = ffi.typeof(name.."*")
  local bases = {...}

  local types = { [name] = true }
  -- cast functions for each base (and parent bases) type
  local casts = { [name] = function(cdata) return cdata end } -- identity cast

  -- build metatype

  local index = {} -- instance index
  local imethods = {} -- class methods index (defined function or direct ffi binding)
  local istatics = {} -- class statics index (defined function or direct ffi binding)

  -- add statics def

  -- auto register new/delete/casts static methods
  statics.new = statics.new or true
  statics.delete = statics.delete or true
  for k,base in pairs(bases) do
    local bmtable = getmetatable(base)
    if bmtable and bmtable.cclass then
      local index = "cast_"..bmtable.name
      statics[index] = statics[index] or true
    end
  end

  for k,v in pairs(statics) do
    -- bind ffi call
    local symbol = name.."_"..k
    local ok = pcall(function() return ffi.cast("void*", C[symbol]) end)
    if ok then -- ffi symbol exists
      local f = C[symbol]
      istatics[k] = f -- add to defindex
      istatics["__c_"..k] = f -- save local ffi binding
    end

    if type(v) ~= "boolean" then -- bind lua function
      istatics[k] = v  -- add to defindex
    end
  end

  -- add special statics
  istatics.name = function() return name end

  -- add methods def

  for k,base in pairs(bases) do
    -- inherit from base
    local bmtable = getmetatable(base) 
    if bmtable and bmtable.cclass then
      -- generate base cast function
      local pctype = bmtable.pctype
      local bname = bmtable.name
      local bcast = istatics["cast_"..bname] -- get defined cast
      if not bcast then -- generate ffi cast
        bcast = function(cdata) return ffi.cast(pctype, cdata) end
      end

      -- add proxied base casts
      for k,v in pairs(bmtable.casts) do
        casts[k] = function(cdata)
          return v(bcast(cdata))
        end
      end
 
      casts[bname] = bcast

      -- methods

      -- copy base defindex
      for k,v in pairs(bmtable.imethods) do
        -- casted function proxy
        local f = function(self, ...)
          return v(bcast(self), ...)
        end

        imethods[k] = f
        index[k] = f -- copy defs
        index["__s_"..k] = f -- save as super
        index["__s_"..bmtable.name.."_"..k] = f -- save as absolute super alias
      end

      -- add base types
      for k,v in pairs(bmtable.types) do
        types[k] = v
      end
    end
  end

  for k,v in pairs(methods) do
    -- bind ffi call
    local symbol = name.."_"..k
    local ok = pcall(function() return ffi.cast("void*", C[symbol]) end)
    if ok then -- ffi symbol exists
      local f = C[symbol]
      imethods[k] = f -- add to defindex
      index[k] = f -- as direct call
      index["__c_"..k] = f -- save local ffi binding
    end

    if type(v) ~= "boolean" then -- bind lua function
      index[k] = v
      imethods[k] = v  -- add to defindex
    end
  end



  -- add special methods

  index.__id = f_id -- __id()

  function index:__type() -- __type()
    return name
  end

  function index:__instanceof(stype) -- __instanceof()
    return types[stype] ~= nil
  end

  function index:__cast(stype) -- __cast()
    local f = casts[stype]
    if f then
      return f(self)
    else
      error("can't up-cast "..self:__type().." to "..stype)
    end
  end

  function index:__get(member) -- __get()
    return index[member]
  end

  -- __data() (return data table per type&instance)
  local data_tables = setmetatable({}, { __mode = "v" })
  local data_refs = setmetatable({}, { __mode = "k" })
  function index:__data()
    -- find ref to data table for this cdata
    local ref = data_refs[self]
    if not ref then
      local id = self:__id()
      -- get data table for this id/address
      local dt = data_tables[id]
      if not dt then
        -- create the data table
        dt = {}
        data_tables[id] = dt
      end

      -- set reference
      ref = dt
      data_refs[self] = ref
    end

    -- return data table
    return ref
  end

  -- setup metatype

  local mtable = {
    __index = index,
    __call = op_call,
    __unm = op_unm,
    __add = op_add,
    __sub = op_sub,
    __mul = op_mul,
    __div = op_div,
    __pow = op_pow,
    __mod = op_mod,
    __eq = op_eq,
    __le = op_le,
    __lt = op_lt,
    __tostring = op_tostring,
    __concat = op_concat
  }

  ffi.metatype(ctype, mtable)

  -- setup class
  
  local instanciate = function(c, ...)
    local new = c.new
    local delete = c.delete
    if new and delete then
      return ffi.gc(new(...), delete)
    else
      error("can't instanciate cclass "..name.." : missing new and/or delete functions")
    end
  end

  return setmetatable({}, { __call = instanciate, __index = istatics, __new_index = function() end, cclass = true, name = name, imethods = imethods, pctype = pctype, casts = casts, types = types })
end

-- SHORTCUTS
setmetatable(cclass, { __call = function(t, ...) 
  return t.new(...)
end})

Luaoop.cclass = cclass
end

return Luaoop
