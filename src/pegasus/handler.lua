local Request = require 'pegasus.request'
local Response = require 'pegasus.response'
local mimetypes = require 'mimetypes'
local lfs = require 'lfs'


function ternary(condition, t, f)
  if condition then return t else return f end
end

local Handler = {}

function Handler:new(callback, location, plugins)
  local handler = {}
  self.__index = self
  handler.callback = callback
  handler.location = location or ''
  handler.plugins = plugins or {}

  local result = setmetatable(handler, self)
  result:pluginsalterRequestResponseMetatable()
  return result
end

function Handler:pluginsalterRequestResponseMetatable()
  local stop = false
  for i, plugin in ipairs(self.plugins) do
    if plugin.alterRequestResponseMetaTable then
      plugin:alterRequestResponseMetaTable(Request, Response)
    end
  end
end

function Handler:pluginsNewRequestResponse(request, response)
  local stop = false
  for i, plugin in ipairs(self.plugins) do
    if plugin.newRequestResponse then
      plugin:newRequestResponse(request, response)
    end
  end
end

function Handler:pluginsBeforeProcess(request, response)
  local stop = false
  for i, plugin in ipairs(self.plugins) do
    if plugin.beforeProcess then
      stop = plugin:beforeProcess(request, response)
      if stop then
        return stop
      end
    end
  end
end

function Handler:pluginsAfterProcess(request, response)
  local stop = false
  for i, plugin in ipairs(self.plugins) do
    if plugin.afterProcess then
      plugin:afterProcess(request, response)
      if stop then
        return stop
      end
    end
  end
end

function Handler:pluginsProcessFile(request, response, filename)
  local stop = false
  for i, plugin in ipairs(self.plugins) do
    if plugin.processFile then
      stop = plugin:processFile(request, response, filename)
      if stop then
        return stop
      end
    end
  end
end

function Handler:processBodyData(data, stayOpen, response)
  local localData = data

  for i, plugin in ipairs(self.plugins or {}) do
    if plugin.processBodyData then
      localData = plugin:processBodyData(localData, stayOpen,
                   response.request,  response)
    end
  end

  return localData
end

function Handler:processRequest(port, client)
  local request = Request:new(port, client)
  local response =  Response:new(client, self)
  response.request = request
  local stop = self:pluginsNewRequestResponse(request, response)

  if stop then
    return
  end

  if request:path() and self.location ~= '' then
    local path = ternary(request:path() == '/' or request:path() == '',
                 'index.html', request:path())
    local filename = '.' .. self.location .. path

    if not lfs.attributes(filename) then
      response:statusCode(404)
      return
    end

    stop = self:pluginsProcessFile(request, response, filename)

    if stop then
      return
    end

    local file = io.open(filename, 'rb')

    if file then
      response:writeFile(file, mimetypes.guess(filename or '') or 'text/html')
    end
  end

  if self.callback then
    response:statusCode(200)
    response.headers = {}
    response:addHeader('Content-Type', 'text/html')
    self.callback(request, response)
  end
end


return Handler
