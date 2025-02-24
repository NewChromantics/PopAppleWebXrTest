struct float4x4
{
	subscript(_ index: Float) -> Float 
	{
		get {
			return 0
		}
		set(newValue)
		{
		}
	}
	
	subscript(_ column: Float,_ row: Float) -> Float
	{
		get {
			return 0
		}
		set(newValue)
		{
		}
	}
	
	var transpose : float4x4
	{
		return float4x4()
	}
	
	var inverse : float4x4
	{
		return float4x4()
	}
	
}

struct ARSessionPolyfill
{
	func run(_ config:ARWorldTrackingConfigurationPolyfill)
	{
	}
	
	var currentFrame : ARFramePolyfill? = nil
}

struct ARCameraPolyfill
{
	var transform = float4x4()
	var projectionMatrix = float4x4()
}

struct ARWorldTrackingConfigurationPolyfill
{
}

struct ARFramePolyfill
{
	var timestamp = 123
	var capturedDepthDataTimestamp = 123
	var camera = ARCameraPolyfill()
}

#if !canImport(ARKit)
typealias simd_float4x4 = float4x4
typealias ARSession = ARSessionPolyfill
typealias ARWorldTrackingConfiguration = ARWorldTrackingConfigurationPolyfill
typealias ARCamera = ARCameraPolyfill
typealias ARFrame = ARFramePolyfill
#endif

