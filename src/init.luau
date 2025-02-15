local gt = require("../luau_packages/greentea_luau")
local task = require('../lune_packages/task')

local NumberBuild = gt.build(gt.number())

local FunctionBuild = gt.build(gt.anyfn())

local QueueBuildType = gt.build(gt.table({
	taskDelay = gt.optional(gt.number()),
	autoRun = gt.optional(gt.boolean()),
	isRun = gt.boolean(),
	queue = gt.struct({ [gt.number()] = gt.anyfn() }),
}))

export type Queue = typeof(setmetatable({} :: typeof(QueueBuildType:type()), {} :: QueueImpl))

type QueueImpl = {
	__index: QueueImpl,
	new: (taskDelay: number?, autoRun: boolean?) -> Queue,
	add: (self: Queue, func: () -> ()) -> (),
	run: (self: Queue) -> (),
	remove: (self: Queue, index: number?) -> (),
}

local Queue = {} :: QueueImpl
Queue.__index = Queue

local function queueIs(value)
	if type(value) == "table" and getmetatable(value) == Queue then
		QueueBuildType:assert(value)

		return true
	end
	return false
end

local QueueType = gt.build(gt.custom(queueIs, "Queue") :: Queue)

function Queue.new(taskDelay, autoRun)
	NumberBuild:assert(taskDelay)
	return setmetatable({
		taskDelay=taskDelay,
		autoRun=autoRun,
		isRun=false,
		queue={},
	}, Queue)
end

function Queue.add(self, func)
	QueueType:assert(self)
	FunctionBuild:assert(func)
	self.queue[#self.queue + 1] = func

	if self.autoRun then
		self:run()
	end
end

function Queue.remove(self, index)
	QueueType:assert(self)
	NumberBuild:assert(index)
	self.queue[index or #self.queue] = nil
end

function Queue.run(self)
	QueueType:assert(self)

	if self.isRun then
		return
	end

	self.isRun = true

	local function run()
		while #self.queue > 0 do
			(table.remove(self.queue, 1) :: any)()
			
			if self.taskDelay and self.taskDelay ~= 0 then
				task.wait(self.taskDelay)
			end

			self.isRun = false
		end
	end

	if self.autoRun then
		task.defer(run)
	else
		run()
	end	
end

return Queue
