local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.MapProjection = GoldMap.MapProjection or {}

local function GetVectorXY(vec, maybeY)
  if vec == nil then
    return nil, nil
  end
  if type(vec) == "number" then
    return vec, maybeY
  end
  if vec.GetXY then
    return vec:GetXY()
  end
  return vec.x, vec.y
end

function GoldMap.MapProjection:IsAvailable()
  return C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D
end

function GoldMap.MapProjection:Init()
  if self.initialized then
    return
  end
  self.transforms = {}
  self.initialized = true
end

function GoldMap.MapProjection:GetTransform(mapID)
  self:Init()

  if self.transforms[mapID] then
    return self.transforms[mapID]
  end

  if not self:IsAvailable() then
    return nil
  end

  local instance00, p00 = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
  local instance10, p10 = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 0))
  local instance01, p01 = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 1))

  local x00, y00 = GetVectorXY(p00)
  local x10, y10 = GetVectorXY(p10)
  local x01, y01 = GetVectorXY(p01)

  if not x00 or not y00 or not x10 or not y10 or not x01 or not y01 then
    return nil
  end

  if instance10 ~= instance00 or instance01 ~= instance00 then
    return nil
  end

  local ax = x10 - x00
  local ay = y10 - y00
  local bx = x01 - x00
  local by = y01 - y00
  local det = (ax * by) - (ay * bx)
  if math.abs(det) < 1e-9 then
    return nil
  end

  local unitsX = math.sqrt((ax * ax) + (ay * ay))
  local unitsY = math.sqrt((bx * bx) + (by * by))

  local transform = {
    instanceID = instance00,
    originX = x00,
    originY = y00,
    ax = ax,
    ay = ay,
    bx = bx,
    by = by,
    det = det,
    worldUnitsPerMap = (unitsX + unitsY) * 0.5,
  }

  self.transforms[mapID] = transform
  return transform
end

function GoldMap.MapProjection:WorldToMap(mapID, worldX, worldY, expectedInstanceID)
  local transform = self:GetTransform(mapID)
  if not transform or not worldX or not worldY then
    return nil
  end

  if expectedInstanceID
    and expectedInstanceID >= 0
    and transform.instanceID
    and transform.instanceID >= 0
    and transform.instanceID ~= expectedInstanceID
  then
    return nil
  end

  local dx = worldX - transform.originX
  local dy = worldY - transform.originY

  local u = ((dx * transform.by) - (dy * transform.bx)) / transform.det
  local v = ((dy * transform.ax) - (dx * transform.ay)) / transform.det

  if u ~= u or v ~= v then
    return nil
  end

  return u, v, transform
end

function GoldMap.MapProjection:ProjectSpawnToMap(spawn, mapID)
  if not spawn or not mapID then
    return nil
  end

  local worldX = tonumber(spawn.wx)
  local worldY = tonumber(spawn.wy)
  if worldX and worldY then
    local px, py = self:WorldToMap(mapID, worldX, worldY, tonumber(spawn.mapID))
    if px and py then
      return px, py
    end
    return nil
  end

  if spawn.x and spawn.y then
    return spawn.x, spawn.y
  end

  return nil
end

function GoldMap.MapProjection:GetApproxWorldUnitsPerMap(mapID)
  local transform = self:GetTransform(mapID)
  if not transform then
    return nil
  end
  return transform.worldUnitsPerMap
end
