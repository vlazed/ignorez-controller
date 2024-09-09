local IZCConstants = {}

-- 2^10 might be an under-guesstimate of the average number of entities for a Gmod sandbox.
-- I don't expect there to be that many entities for Gmod animators
IZCConstants.ENTITY_BIT_COUNT = 10

-- Measured from the look vector, the angle beyond which we toggle the ignorez parameter
-- If this is set to +/-180 degrees and above (or below), we do not control anything, and
-- we skip dot product calculations.
IZCConstants.MAX_LOOK_ANGLE = 115

-- Whether we switch the ignorez parameter
-- We give the option for users to switch the see-through behavior of materials if a predicate
-- is true
IZCConstants.IS_INVERTED = false

-- Whether we should use a ragdoll's eye angles (hopefully not changed eyetarget)
-- By default, we use the world look vector obtained from Entity:EyeAngles as we assume proper
-- eye orientation for the given ragdoll If this is false, the user can specify their reference
-- heading with respect to a specific bone angle (on or offset by some degrees)
IZCConstants.USE_EYE_ANGLE = true

-- The name of the bone to use for reference heading if USE_EYE_ANGLE is false
-- The default id is arbitrary. The CPanel frontend automatically replaces this value with
-- a valid bone id corresponding to the ragdoll's head.
-- The frontend may be used to change the bone for dot product calculations
IZCConstants.DEFAULT_BONE_ID = 1

-- The offset from the bone's reference heading if USE_EYE_ANGLE is false
IZCConstants.DEFAULT_ANGLE_OFFSET = angle_zero

return IZCConstants
