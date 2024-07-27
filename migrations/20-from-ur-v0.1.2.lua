for _, reactor in pairs(global.reactors) do
    reactor.core = nil
    reactor.core_id = nil
    reactor.entity.temperature = reactor.signals.parameters.core_temperature.count
end
