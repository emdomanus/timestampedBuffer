--!strict
--!optimize 2

local TimestampedBuffer = require(script.components.timestampedBuffer.shared.timestampedBuffer)
local TimestampedBufferTypes =
	require(script.types.components.timestampedBuffer.shared.timestampedBuffer)

export type TimestampedBuffer<T> = TimestampedBufferTypes.TimestampedBuffer<T>

return TimestampedBuffer
