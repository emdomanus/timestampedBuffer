--!strict

local TimestampedBuffer = require("../../.verify/src/package")
local BufferTypes =
	require("../../.verify/src/types/components/timestampedBuffer/shared/timestampedBuffer")
local TestTypes = require("../types")
local Examples = require("./examples")

type TimestampedBuffer<T> = TimestampedBuffer.TimestampedBuffer<T>
type TimestampedBufferImpl<T> = BufferTypes.TimestampedBufferImpl<T>
type Sample = TestTypes.Sample
type ReferenceEntry = TestTypes.ReferenceEntry

local passed = 0
local function test(name: string, run: () -> ()): ()
	run()
	passed += 1
	print(`PASS {name}`)
end

local function equal<T>(actual: T, expected: T): ()
	assert(actual == expected, `expected {tostring(expected)}, got {tostring(actual)}`)
end

local function rejects(run: () -> ()): ()
	local ok = pcall(run)
	assert(not ok, "expected input rejection")
end

local function pair<T>(expected: T?, expectedTime: number?, value: T?, time: number?): ()
	equal(value, expected)
	equal(time, expectedTime)
end

local function bracket<T>(
	history: TimestampedBuffer<T>,
	query: number,
	a: T?,
	ta: number?,
	b: T?,
	tb: number?
): ()
	local actualA, actualTa, actualB, actualTb = history:bracket(query)
	pair(a, ta, actualA, actualTa)
	pair(b, tb, actualB, actualTb)
end

test("empty and single entry", function()
	local h: TimestampedBuffer<number> = TimestampedBuffer.new(3)
	equal(h:count(), 0)
	pair(nil, nil, h:oldest())
	pair(nil, nil, h:newest())
	pair(nil, nil, h:at(1))
	pair(nil, nil, h:popOldest())
	pair(nil, nil, h:latestAtOrBefore(0))
	bracket(h, 0, nil, nil, nil, nil)
	equal(h:evictBefore(10), 0)
	pair(nil, nil, h:push(7, 2))
	pair(7, 2, h:oldest())
	pair(7, 2, h:newest())
	pair(nil, nil, h:latestAtOrBefore(1))
	pair(7, 2, h:latestAtOrBefore(2))
	pair(7, 2, h:latestAtOrBefore(3))
	bracket(h, 1, nil, nil, nil, nil)
	bracket(h, 2, 7, 2, 7, 2)
	bracket(h, 3, nil, nil, nil, nil)
	pair(nil, nil, h:at(2))
end)

test("capacity one and repeated wraparound", function()
	for capacity = 1, 7 do
		local h: TimestampedBuffer<number> = TimestampedBuffer.new(capacity)
		for i = 1, 100 do
			local evicted, time = h:push(i, i * 0.5)
			if i > capacity then
				pair(i - capacity, (i - capacity) * 0.5, evicted, time)
			else
				pair(nil, nil, evicted, time)
			end
			equal(h:count(), math.min(i, capacity))
			local first = math.max(1, i - capacity + 1)
			for j = 1, h:count() do
				pair(first + j - 1, (first + j - 1) * 0.5, h:at(j))
			end
			pair(first, first * 0.5, h:oldest())
			pair(i, i * 0.5, h:newest())
			bracket(h, i * 0.5, i, i * 0.5, i, i * 0.5)
		end
	end
end)

test("uneven intervals and duplicate newest exact hit across wrap", function()
	local h: TimestampedBuffer<number> = TimestampedBuffer.new(5)
	for i, time in { -10, -5, 0, 0.25, 4, 4, 9 } do
		h:push(i, time)
	end
	pair(nil, nil, h:latestAtOrBefore(-1))
	pair(4, 0.25, h:latestAtOrBefore(3))
	pair(6, 4, h:latestAtOrBefore(4))
	pair(7, 9, h:latestAtOrBefore(100))
	bracket(h, -1, nil, nil, nil, nil)
	bracket(h, 0, 3, 0, 3, 0)
	bracket(h, 2, 4, 0.25, 5, 4)
	bracket(h, 4, 6, 4, 6, 4)
	bracket(h, 5, 6, 4, 7, 9)
	bracket(h, 9, 7, 9, 7, 9)
	bracket(h, 10, nil, nil, nil, nil)
	for i = 8, 20 do
		h:push(i, 9)
	end
	bracket(h, 9, 20, 9, 20, 9)
	pair(20, 9, h:latestAtOrBefore(9))
end)

test("strict cutoff and mixed capacity eviction", function()
	local h: TimestampedBuffer<number> = TimestampedBuffer.new(4)
	for i, time in { 1, 2, 2, 8, 10 } do
		h:push(i, time)
	end
	equal(h:evictBefore(2), 0)
	equal(h:evictBefore(3), 2)
	pair(4, 8, h:oldest())
	h:push(6, 11)
	h:push(7, 12)
	pair(4, 8, h:push(8, 13))
	equal(h:evictBefore(13), 3)
	pair(8, 13, h:oldest())
	equal(h:evictBefore(14), 1)
	pair(nil, nil, h:popOldest())
	-- Empty storage has no timestamp watermark.
	pair(nil, nil, h:push(9, -10))
end)

test("invalid inputs are rejected before mutation", function()
	for _, capacity in { 0, -1, 1.5, math.huge, -math.huge, 0 / 0 } do
		rejects(function()
			TimestampedBuffer.new(capacity)
		end)
	end
	local h: TimestampedBuffer<number?> = TimestampedBuffer.new(2)
	h:push(1, 10)
	h:push(2, 20)
	local impl = h :: TimestampedBufferImpl<number?>
	local head = impl._head
	for _, time in { 19, math.huge, -math.huge, 0 / 0 } do
		rejects(function()
			h:push(99, time)
		end)
		equal(impl._head, head)
		equal(h:count(), 2)
		pair(1, 10, h:at(1))
		pair(2, 20, h:at(2))
	end
	rejects(function()
		h:push(nil, 30)
	end)
	for _, time in { math.huge, -math.huge, 0 / 0 } do
		rejects(function()
			h:evictBefore(time)
		end)
		rejects(function()
			h:latestAtOrBefore(time)
		end)
		rejects(function()
			h:bracket(time)
		end)
	end
	for _, index in { 0, -1, 1.5, math.huge, 0 / 0 } do
		rejects(function()
			h:at(index)
		end)
	end
	equal(h:count(), 2)
	pair(1, 10, h:popOldest())
	rejects(function()
		h:push(3, 19)
	end)
	pair(2, 20, h:popOldest())
	pair(nil, nil, h:push(3, -1))
end)

test("clear and removal release references and reuse arrays", function()
	local h: TimestampedBuffer<Sample> = TimestampedBuffer.new(3)
	local impl = h :: TimestampedBufferImpl<Sample>
	local values, times = impl._values, impl._times
	for i = 1, 3 do
		h:push({ lifetime = 1, position = i }, i)
	end
	local head = impl._head
	h:popOldest()
	equal(values[head], nil)
	equal(times[head], nil)
	h:evictBefore(3)
	equal(values[2], nil)
	equal(times[2], nil)
	h:clear()
	h:clear()
	equal(h:count(), 0)
	equal(impl._values, values)
	equal(impl._times, times)
	for i = 1, 3 do
		equal(values[i], nil)
		equal(times[i], nil)
	end
	local sample: Sample = { lifetime = 2, position = 8 }
	h:push(sample, -5)
	pair(sample, -5, h:oldest())
end)

test("false is a valid payload", function()
	local h: TimestampedBuffer<boolean> = TimestampedBuffer.new(1)
	h:push(false, 0)
	bracket(h, 0, false, 0, false, 0)
	pair(false, 0, h:push(true, 1))
end)

test("consumer examples: lifetime boundary, interpolation and explicit reset", function()
	Examples.recycle()
	local h: TimestampedBuffer<number> = TimestampedBuffer.new(4)
	h:push(10, 1)
	h:push(30, 3)
	equal(Examples.interpolate(h, 2), 20)
	equal(Examples.interpolate(h, 1), 10)
	equal(Examples.interpolate(h, 4), nil)
	h:clear()
	h:push(50, -10)
	equal(Examples.interpolate(h, 2), nil)
	equal(Examples.interpolate(h, -10), 50)
	local samples: TimestampedBuffer<Sample> = TimestampedBuffer.new(4)
	samples:push({ lifetime = 1, position = 0 }, 0)
	samples:push({ lifetime = 1, position = 10 }, 1)
	samples:push({ lifetime = 2, position = 100 }, 2)
	equal(Examples.hurtboxPosition(samples, 0.5), 5)
	equal(Examples.hurtboxPosition(samples, 1.5), nil)
	equal(Examples.hurtboxPosition(samples, 2), 100)
end)

test("owner retains one strict predecessor", function()
	local h: TimestampedBuffer<number> = TimestampedBuffer.new(8)
	for i, time in { 1, 2, 2, 4, 7 } do
		h:push(i, time)
	end
	Examples.retainPredecessor(h, 4)
	pair(3, 2, h:oldest())
	bracket(h, 3, 3, 2, 4, 4)
	equal(h:evictBefore(4), 1)
	bracket(h, 3, nil, nil, nil, nil)
end)

test("mixed operations agree with chronological reference model", function()
	local seed = 12345
	local function random(maximum: number): number
		seed = (seed * 16807) % 2147483647
		return seed % maximum + 1
	end
	for _, capacity in { 1, 2, 3, 8, 32, 127 } do
		local h: TimestampedBuffer<number> = TimestampedBuffer.new(capacity)
		local reference: { ReferenceEntry } = {}
		local time = 0
		for iteration = 1, 3000 do
			local action = random(100)
			if action <= 60 then
				time += (random(5) - 1) * 0.25
				local removed = nil
				if #reference == capacity then
					removed = table.remove(reference, 1)
				end
				pair(
					if removed then removed.value else nil,
					if removed then removed.time else nil,
					h:push(iteration, time)
				)
				table.insert(reference, { value = iteration, time = time })
			elseif action <= 73 then
				local removed = table.remove(reference, 1)
				pair(
					if removed then removed.value else nil,
					if removed then removed.time else nil,
					h:popOldest()
				)
			elseif action <= 86 then
				local cutoff = time - random(15) * 0.25
				local removed = 0
				while #reference > 0 and reference[1].time < cutoff do
					table.remove(reference, 1)
					removed += 1
				end
				equal(h:evictBefore(cutoff), removed)
			elseif action <= 89 then
				h:clear()
				table.clear(reference)
				time = -random(100)
			elseif #reference > 0 then
				rejects(function()
					h:push(-1, reference[#reference].time - 1)
				end)
			end
			equal(h:count(), #reference)
			for index, entry in reference do
				pair(entry.value, entry.time, h:at(index))
			end
			pair(nil, nil, h:at(#reference + 1))
			local first, last = reference[1], reference[#reference]
			pair(if first then first.value else nil, if first then first.time else nil, h:oldest())
			pair(if last then last.value else nil, if last then last.time else nil, h:newest())
			for _, query in
				{
					time - random(30) * 0.25,
					time,
					time + 1,
					if first then first.time - 1 else time - 1,
				}
			do
				local olderIndex = 0
				for index, entry in reference do
					if entry.time <= query then
						olderIndex = index
					end
				end
				local older = reference[olderIndex]
				pair(
					if older then older.value else nil,
					if older then older.time else nil,
					h:latestAtOrBefore(query)
				)
				local newer = if older and older.time == query
					then older
					else reference[olderIndex + 1]
				if older and newer then
					bracket(h, query, older.value, older.time, newer.value, newer.time)
				else
					bracket(h, query, nil, nil, nil, nil)
				end
			end
		end
	end
end)

print(`{passed} tests passed; reference model: 18,000 mixed operations, 72,000 lookup pairs`)
