local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.Throttle = GoldMap.Throttle or {}

function GoldMap.Throttle:New(delaySeconds, fn)
  local obj = {
    delay = delaySeconds or 0.1,
    callback = fn,
    timer = nil,
  }
  setmetatable(obj, { __index = self })
  return obj
end

function GoldMap.Throttle:Run(...)
  local args = { ... }

  if self.timer then
    self.timer:Cancel()
  end

  self.timer = C_Timer.NewTimer(self.delay, function()
    self.timer = nil
    if self.callback then
      self.callback(unpack(args))
    end
  end)
end

function GoldMap.Throttle:Cancel()
  if self.timer then
    self.timer:Cancel()
    self.timer = nil
  end
end
