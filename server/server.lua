local key = GetConvar('datadog:key', '')
local response = {
	[400] = 'bad request',
	[401] = 'unauthorized',
	[403] = 'forbidden',
	[404] = 'not found',
	[405] = 'method not allowed',
	[408] = 'request timeout',
	[413] = 'payload too large',
	[429] = 'too many requests',
	[500] = 'internal server error',
	[502] = 'gateway unavailable',
	[503] = 'service unavailable'
}

local site = ('https://http-intake.logs.%s/api/v2/logs'):format(GetConvar('datadog:site', 'datadoghq.com'))

if key ~= '' then
	function logs(message, source, name, ...)
		local ddtags = string.strjoin(',', string.tostringall(...))
		PerformHttpRequest(site, function(status)
			if status ~= 202 then
				print(('unable to submit logs to %s (%s)'):format(site, response[status]))
			end
		end, 'POST', json.encode({
			hostname = GetConvar('datadog:hostname', 'RPRP:Development'),
			service = name,
			message = message,
			ddsource = source,
			ddtags = ddtags
		}), {
			['Content-Type'] = 'application/json',
			['DD-API-KEY'] = key
		})
	end
else
    function logs(message, source, ...)
        local tag = tagEveryone ~= nil and tagEveryone or false

        local webHook = Config.Webhooks[name] ~= nil and Config.Webhooks[name] or Config.Webhooks["default"]
    
        local embedData = {
            {
                ["title"] = title,
                ["color"] = Config.Colors[color] ~= nil and Config.Colors[color] or Config.Colors["default"],
                ["footer"] = {
                    ["text"] = os.date("%c"),
                },
                ["description"] = message,
                ["author"] = {
                    ["name"] = 'RPRP Logs',
                    ["icon_url"] = "https://cdn.discordapp.com/icons/592751561185296408/8d323b65d82c4c134ffee4742408886d.webp?size=96",
                },
            }
        }
        PerformHttpRequest(webHook, function(err, text, headers) end, 'POST', json.encode({ username = "Fiscal",embeds = embedData}), { ['Content-Type'] = 'application/json' })
        Citizen.Wait(100)
        if tag then
            PerformHttpRequest(webHook, function(err, text, headers) end, 'POST', json.encode({ username = "Fiscal", content = "@everyone"}), { ['Content-Type'] = 'application/json' })
        end
    end
end

function GetPlayerHighTrustedIdentifiers(player, getIp)
	local highTrustedIdentifiers = { }
	local size = 0

	local identifiers = GetPlayerIdentifiers(player)

	for _, identifier in ipairs(identifiers) do
		local idType = identifier:sub(1, identifier:find(':') - 1)

		if not getIp and idType == "ip" then break end

		highTrustedIdentifiers[idType] = identifier

		size = size + 1
	end

	return highTrustedIdentifiers, size
end

RegisterNetEvent("log:discord:webhook", function(webhook, ...)
    local serverId = source
    local identifier, size = GetPlayerHighTrustedIdentifiers(serverId)

    identifier.discord = identifier.discord:gsub("discord:", "")

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({ username = "Fiscal", content = string.format("<@%s>", identifier.discord)}), { ['Content-Type'] = 'application/json' })
end)

RegisterServerEvent('log:server:sendLog')
AddEventHandler('log:server:sendLog', function(citizenid, logtype, data)
    local dataString = ""
    data = data ~= nil and data or {}
    for key,value in pairs(data) do 
        if dataString ~= "" then
            dataString = dataString .. "&"
        end
        dataString = dataString .. key .."="..value
    end

    logs(dataString, citizenid, logtype)
end)

RegisterServerEvent('log:server:CreateLog')
AddEventHandler('log:server:CreateLog', function(name, title, color, message, tagEveryone)
    logs(message, source, name, title, color, tagEveryone)
end)