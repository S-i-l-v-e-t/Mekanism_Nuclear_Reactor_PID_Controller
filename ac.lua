reactor = peripheral.find("fissionReactorLogicAdapter")
maxBurnRate = reactor.getMaxBurnRate()
PIDcoe = {0.0000001,0.05,0.05}
tgtCoolantLevel = 0.2
intgTime = 150

function LuaQueue()
    return setmetatable({_data = {}},_LuaQueueMeta);
end

_LuaQueueMeta = {
    __index = {
        Enque = function(self,x)
            table.insert(self._data,x);
        end;
        Deque = function (self)
            return table.remove(self._data,1);
        end;
        Count = function(self)
            return #self._data;
        end;
        Sum = function(self)
            local result = 0
            for _,v in pairs(self._data) do
                result = result+v
            end
            return result
        end;
        Item = function (self,idx)
            return self._data[idx]
        end;
    };
    __tostring = function(self)
        local str = "-----\n";
        for i,v in ipairs(self._data) do
            str = str .. i .. " " ..tostring(v) .. "\n";
        end
        return str .. "-----";
    end;
}

function getTemp()
    return reactor.getTemperature()
end

tgtCoolant = reactor.getCoolantCapacity()*tgtCoolantLevel

function getTC()
    return reactor.getHeatCapacity()
    
end

function getEffciency()
    return reactor.getBoilEfficiency()
    
end

function getTargetTemperature(speed)
    return ((speed*1000)/getEffciency()) + 373.15
    
end

function getHeatNeeded(tgtTemp)
    return (tgtTemp-getTemp())*getTC()+reactor.getEnvironmentalLoss()
    
end
function getBurnNeeded(heat)
    return heat/1000000
    
end

function getCurCoolant()
    return reactor.getCoolant()["amount"]
end

function setRate(value)
    if value>0 then
        if value<maxBurnRate-0.1 then
            reactor.setBurnRate(value)
        else
            reactor.setBurnRate(maxBurnRate)
        end
    else
        reactor.setBurnRate(0)
    end
end

function calcDeltaCoolant()
    return getCurCoolant()-tgtCoolant
end


function Failsafe()
    if getTemp() >= 1000 and reactor.getStatus() then
        reactor.scram()
    end
end

function initialize()
    reactor.activate()
end

pDelta = 0
iDelta = 0
dDelta = 0
queue = LuaQueue() 
function Control()
    pDelta = calcDeltaCoolant()*PIDcoe[1]
    queue.Enque(queue,pDelta)
    if queue.Count(queue)>intgTime then
        queue.Deque(queue)
    end
    if queue.Count(queue)>=3 then
        iDelta = queue.Sum(queue)*PIDcoe[2]
        dDelta = (queue.Item(queue,queue.Count(queue))-queue.Item(queue,queue.Count(queue)-1))*PIDcoe[3]
    end
    totalError = pDelta+iDelta+dDelta
    setRate(getBurnNeeded(getHeatNeeded(getTargetTemperature(totalError))))
end

initialize()
while true do
    Failsafe()
    Control()
end