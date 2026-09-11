--!strict

export type TimestampedBuffer<T> = {
	push: (self: TimestampedBuffer<T>, value: T, time: number) -> (T?, number?),
	popOldest: (self: TimestampedBuffer<T>) -> (T?, number?),
	evictBefore: (self: TimestampedBuffer<T>, cutoff: number) -> number,
	oldest: (self: TimestampedBuffer<T>) -> (T?, number?),
	newest: (self: TimestampedBuffer<T>) -> (T?, number?),
	at: (self: TimestampedBuffer<T>, index: number) -> (T?, number?),
	count: (self: TimestampedBuffer<T>) -> number,
	latestAtOrBefore: (self: TimestampedBuffer<T>, time: number) -> (T?, number?),
	bracket: (self: TimestampedBuffer<T>, time: number) -> (T?, number?, T?, number?),
	clear: (self: TimestampedBuffer<T>) -> (),
}

export type TimestampedBufferImpl<T> = TimestampedBuffer<T> & {
	_values: { T? },
	_times: { number? },
	_head: number,
	_count: number,
	_capacity: number,
}

return {}
