--!strict

local TimestampedBuffer = require("../.verify/src/package")
local TestTypes = require("../tests/types")

type TimestampedBuffer<T> = TimestampedBuffer.TimestampedBuffer<T>
type Sample = TestTypes.Sample

local iterations = 200000
local checksum = 0
print(`Each timed loop: {iterations} iterations; seconds from os.clock; Lune host timing`)
print("capacity,append_s,latest_s,bracket_s,mixed_s,recycled_append_s")
for _, capacity in { 1, 32, 128, 1024 } do
	local h: TimestampedBuffer<number> = TimestampedBuffer.new(capacity)
	local time = 0
	for i = 1, capacity + 1000 do
		time += (i % 7) * 0.003
		h:push(i, time)
	end
	local start = os.clock()
	for i = 1, iterations do
		time += (i % 7) * 0.003
		h:push(i, time)
	end
	local appendSeconds = os.clock() - start
	local _, oldestTime = h:oldest()
	assert(oldestTime ~= nil, "expected populated history")
	local width = time - oldestTime
	start = os.clock()
	for i = 1, iterations do
		local value = h:latestAtOrBefore(oldestTime + width * (i % 101) / 100)
		checksum += value or 0
	end
	local latestSeconds = os.clock() - start
	start = os.clock()
	for i = 1, iterations do
		local value = h:bracket(oldestTime + width * (i % 101) / 100)
		checksum += value or 0
	end
	local bracketSeconds = os.clock() - start
	start = os.clock()
	for i = 1, iterations do
		time += (i % 7) * 0.003
		h:push(i, time)
		if i % 31 == 0 then
			h:evictBefore(time - capacity * 0.004)
		end
		if i % 11 == 0 then
			h:popOldest()
		end
		local value = h:latestAtOrBefore(time - 0.01)
		checksum += value or 0
	end
	local mixedSeconds = os.clock() - start
	local records: TimestampedBuffer<Sample> = TimestampedBuffer.new(capacity)
	for i = 1, capacity do
		records:push({ lifetime = 1, position = i }, i)
	end
	local spare: Sample = { lifetime = 1, position = 0 }
	start = os.clock()
	for i = 1, iterations do
		spare.position = i
		local evicted = records:push(spare, capacity + i)
		spare = evicted :: Sample
	end
	local recycledSeconds = os.clock() - start
	print(
		string.format(
			"%d,%.6f,%.6f,%.6f,%.6f,%.6f",
			capacity,
			appendSeconds,
			latestSeconds,
			bracketSeconds,
			mixedSeconds,
			recycledSeconds
		)
	)
end
print(`checksum {checksum}; no memory or allocator instrumentation used`)
