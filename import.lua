log = {}

local scope = { }

local KEY = GetConvar('datadog:key', '')
local URL = ('https://http-intake.logs.%s/api/v2/logs'):format(GetConvar('datadog:site', 'datadoghq.com'))

function log:init()
    self.service = GetCurrentResourceName()
end

function log:scope()
    return scope.new()
end

function log:captureMessage(message, scope)    
    if not key then return end
    local payload =
    {
        message = message,

        hostname = GetConvar('datadog:hostname', 'development'),
        service = self.service,

        context = scope and scope:getContexts() or nil
    }

    local cb = function(errorCode, resultData, resultHeaders)
        if errorCode ~= 202 then
            print(('unable to submit logs to %s (%s) (%s) (%s)'):format(URL, errorCode, tostring(resultData), tostring(json.encode(resultHeaders))))
        end
    end

    local encodedPayload = json.encode(payload)

    PerformHttpRequest(URL, cb, 'POST', encodedPayload,
    {
        ['Content-Type'] = 'application/json',
        ['DD-API-KEY'] = KEY
    })
end

function scope.new()

    local self =
    {
        contexts = { },
    }

    return setmetatable(self, { __index = scope })
end

function scope:getContext(key)
    return self.contexts[key]
end

function scope:getContexts()
    return self.contexts
end

function scope:setContext(key, data)
    local oldData = self.contexts[key]

    self.contexts[key] = oldData and table_merge(oldData, data) or data
end

function scope:setUser(data)
    local isUserInstance = data and data.getId ~= nil

    if isUserInstance then
        local user = data

        local steamIdentity = user.getIdentity('steam')
        local steamNickname = steamIdentity and steamIdentity.last_nickname or nil

        local discordIdentity = user.getIdentity('discord')
        local discordNickname = discordIdentity and discordIdentity.last_nickname or nil

        data =
        {
            userId = user.getId(),
            usernameSteam = steamNickname,
            usernameDiscord = discordNickname,
            
            characterId = user.getActiveCharacterId(),
            characterName = user.getFullname(),
        }
    end

    self:setContext('user', data)
end

function table_merge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            table_merge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end

log:init()