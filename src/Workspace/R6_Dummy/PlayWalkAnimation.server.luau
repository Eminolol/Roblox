local dummy = script.Parent
local humanoid = dummy:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local walkAnim = dummy:WaitForChild("WalkAnimation")

local track = animator:LoadAnimation(walkAnim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Movement
track:Play()
