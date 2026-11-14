--- Picks the running framework. Each frameworks/<name>/ file only loads for its own framework and fills
--- Framework.Server / Framework.Client. Unlike hype-core nothing here is exported: it's for this resource only.
Framework = {
    Name = nil,
    Server = {},
    Client = {},
}

if GetResourceState('es_extended') == 'started' then
    Framework.Name = 'es_extended'
elseif GetResourceState('qbx_core') == 'started' then
    Framework.Name = 'qbx_core'
elseif GetResourceState('qb-core') == 'started' then
    Framework.Name = 'qb-core'
else
    print("^1[hype-dedector] No supported framework found (es_extended, qbx_core, qb-core).^0")
end
