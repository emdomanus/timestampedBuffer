--!strict

local TimestampedBuffer = require("../../.verify/src/package")
local TestTypes = require("../types")

type TimestampedBuffer<T> = TimestampedBuffer.TimestampedBuffer<T>
type Sample = TestTypes.Sample

local Examples = {}

function Examples.interpolate(history: TimestampedBuffer<number>, time: number): number?
	local a, ta, b, tb = history:bracket(time)
	if a == nil or ta == nil or b == nil or tb == nil then
		return nil
	end
	if ta == tb then
		return a
	end
	return a + (b - a) * ((time - ta) / (tb - ta))
end

function Examples.hurtboxPosition(history: TimestampedBuffer<Sample>, time: number): number?
	local a, ta, b, tb = history:bracket(time)
	if a == nil or ta == nil or b == nil or tb == nil or a.lifetime ~= b.lifetime then
		return nil
	end
	if ta == tb then
		return a.position
	end
	return a.position + (b.position - a.position) * ((time - ta) / (tb - ta))
end

function Examples.recycle(): ()
	local history: TimestampedBuffer<Sample> = TimestampedBuffer.new(4)
	for i = 1, 4 do
		history:push({ lifetime = 1, position = i }, i)
	end
	-- Capacity + one caller-owned spare; no table construction inside this loop.
	local spare: Sample = { lifetime = 1, position = 0 }
	for i = 5, 1000 do
		spare.position = i
		local evicted, time = history:push(spare, i)
		assert(evicted ~= nil and time == i - 4, "expected reusable oldest record")
		spare = evicted
	end
	local oldest, time = history:popOldest()
	assert(oldest ~= nil and oldest.position == 997 and time == 997, "unexpected oldest sample")
	-- Returned records may be reused only after all other readers release them.
end

function Examples.retainPredecessor(history: TimestampedBuffer<number>, cutoff: number): ()
	-- Leave the newest predecessor below the boundary; preserve samples at cutoff.
	while history:count() >= 2 do
		local _, secondTime = history:at(2)
		if secondTime == nil or secondTime >= cutoff then
			break
		end
		history:popOldest()
	end
end

return Examples
