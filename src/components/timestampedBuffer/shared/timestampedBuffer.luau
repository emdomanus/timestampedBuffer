--!strict
--!optimize 2
--!native

local TimestampedBufferTypes = require(
	script.Parent.Parent.Parent.Parent.types.components.timestampedBuffer.shared.timestampedBuffer
)

type TimestampedBuffer<T> = TimestampedBufferTypes.TimestampedBuffer<T>
type TimestampedBufferImpl<T> = TimestampedBufferTypes.TimestampedBufferImpl<T>
type TimestampedBufferModule = {
	new: <T>(capacity: number) -> TimestampedBuffer<T>,
}

local function assertFinite(time: number): ()
	assert(type(time) == "number" and time > -math.huge and time < math.huge, "time must be finite")
end

local function slot<T>(self: TimestampedBufferImpl<T>, index: number): number
	return (self._head + index - 2) % self._capacity + 1
end

-- Number of entries <= time; the last of these is the newest inserted exact hit.
local function upperBound<T>(self: TimestampedBufferImpl<T>, time: number): number
	local low = 0
	local high = self._count
	while low < high do
		local middle = math.floor((low + high) / 2)
		if (self._times[slot(self, middle + 1)] :: number) <= time then
			low = middle + 1
		else
			high = middle
		end
	end
	return low
end

local TimestampedBuffer = {}
TimestampedBuffer.__index = TimestampedBuffer

function TimestampedBuffer.new<T>(capacity: number): TimestampedBuffer<T>
	assert(
		type(capacity) == "number" and capacity > 0 and capacity < math.huge and capacity % 1 == 0,
		"capacity must be a positive finite integer"
	)
	local self: TimestampedBufferImpl<T> = setmetatable(
		{
			_values = table.create(capacity),
			_times = table.create(capacity),
			_head = 1,
			_count = 0,
			_capacity = capacity,
		} :: TimestampedBufferImpl<T>,
		TimestampedBuffer
	) :: any
	return self
end

function TimestampedBuffer.push<T>(
	self: TimestampedBufferImpl<T>,
	value: T,
	time: number
): (T?, number?)
	assertFinite(time)
	assert(value ~= nil, "payload must not be nil")
	if self._count > 0 then
		assert(
			time >= (self._times[slot(self, self._count)] :: number),
			"timestamps must not decrease"
		)
	end

	local index = slot(self, self._count + 1)
	local evictedValue = self._values[index]
	local evictedTime = self._times[index]
	self._values[index] = value
	self._times[index] = time
	if self._count == self._capacity then
		self._head = self._head % self._capacity + 1
	else
		self._count += 1
	end
	return evictedValue, evictedTime
end

function TimestampedBuffer.popOldest<T>(self: TimestampedBufferImpl<T>): (T?, number?)
	if self._count == 0 then
		return nil, nil
	end
	local index = self._head
	local value = self._values[index]
	local time = self._times[index]
	self._values[index] = nil
	self._times[index] = nil
	self._head = index % self._capacity + 1
	self._count -= 1
	return value, time
end

function TimestampedBuffer.evictBefore<T>(self: TimestampedBufferImpl<T>, cutoff: number): number
	assertFinite(cutoff)
	local removed = 0
	while self._count > 0 and (self._times[self._head] :: number) < cutoff do
		TimestampedBuffer.popOldest(self)
		removed += 1
	end
	return removed
end

function TimestampedBuffer.oldest<T>(self: TimestampedBufferImpl<T>): (T?, number?)
	if self._count == 0 then
		return nil, nil
	end
	return self._values[self._head], self._times[self._head]
end

function TimestampedBuffer.newest<T>(self: TimestampedBufferImpl<T>): (T?, number?)
	if self._count == 0 then
		return nil, nil
	end
	local index = slot(self, self._count)
	return self._values[index], self._times[index]
end

function TimestampedBuffer.at<T>(self: TimestampedBufferImpl<T>, index: number): (T?, number?)
	assert(
		type(index) == "number" and index > 0 and index < math.huge and index % 1 == 0,
		"index must be a positive finite integer"
	)
	if index > self._count then
		return nil, nil
	end
	local physical = slot(self, index)
	return self._values[physical], self._times[physical]
end

function TimestampedBuffer.count<T>(self: TimestampedBufferImpl<T>): number
	return self._count
end

function TimestampedBuffer.latestAtOrBefore<T>(
	self: TimestampedBufferImpl<T>,
	time: number
): (T?, number?)
	assertFinite(time)
	local index = upperBound(self, time)
	if index == 0 then
		return nil, nil
	end
	local physical = slot(self, index)
	return self._values[physical], self._times[physical]
end

function TimestampedBuffer.bracket<T>(
	self: TimestampedBufferImpl<T>,
	time: number
): (T?, number?, T?, number?)
	assertFinite(time)
	local index = upperBound(self, time)
	if index == 0 then
		return nil, nil, nil, nil
	end
	local older = slot(self, index)
	local olderTime = self._times[older]
	local olderValue = self._values[older]
	if olderTime == time then
		return olderValue, olderTime, olderValue, olderTime
	end
	if index == self._count then
		return nil, nil, nil, nil
	end
	local newer = slot(self, index + 1)
	return olderValue, olderTime, self._values[newer], self._times[newer]
end

function TimestampedBuffer.clear<T>(self: TimestampedBufferImpl<T>): ()
	table.clear(self._values)
	table.clear(self._times)
	self._head = 1
	self._count = 0
end

return TimestampedBuffer :: TimestampedBufferModule
