local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.Cache = GoldMap.Cache or {}

function GoldMap.Cache:New(defaultTTL)
  local obj = {
    ttl = defaultTTL or 0,
    values = {},
  }
  setmetatable(obj, { __index = self })
  return obj
end

function GoldMap.Cache:Set(key, value, ttl)
  self.values[key] = {
    value = value,
    expiresAt = (ttl or self.ttl or 0) > 0 and (GetServerTime() + (ttl or self.ttl)) or 0,
  }
end

function GoldMap.Cache:Get(key)
  local entry = self.values[key]
  if not entry then
    return nil
  end

  if entry.expiresAt > 0 and GetServerTime() > entry.expiresAt then
    self.values[key] = nil
    return nil
  end

  return entry.value
end

function GoldMap.Cache:Clear()
  self.values = {}
end
