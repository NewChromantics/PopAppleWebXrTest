import ARKit
import WebKit

func MatrixToFloatArray(_ float4x4:simd_float4x4) -> [Float]
{
	let array : [Float] = [
		float4x4[0,0],
		float4x4[0,1],
		float4x4[0,2],
		float4x4[0,3],

		float4x4[1,0],
		float4x4[1,1],
		float4x4[1,2],
		float4x4[1,3],

		float4x4[2,0],
		float4x4[2,1],
		float4x4[2,2],
		float4x4[2,3],

		float4x4[3,0],
		float4x4[3,1],
		float4x4[3,2],
		float4x4[3,3],
	]
	return array
}

class WebxrController : NSObject, WKScriptMessageHandlerWithReply
{
	static let messageName : String = "AppleXr"
	let session = ARSession()
	
	override init()
	{
		session.run( ARWorldTrackingConfiguration()/*, options:ARSession.RunOptions */)
		
	}
	
	static func WriteCameraMeta(camera:ARCamera,meta:inout [String:Any])
	{
		//	gr: these matricies are correct when phone in landscape. need to correct the projection matrix (i believe)
		//		based on orientation
		//		I'm sure i did this in PopCameraDevice!

		let WorldTransform = camera.transform.transpose.inverse
		meta["WorldTransform"] = MatrixToFloatArray(WorldTransform)

		let ProjectionMatrix = camera.projectionMatrix
		meta["ProjectionMatrix"] = MatrixToFloatArray(ProjectionMatrix)
	}
	
	func HandleMessage(_ message:WKScriptMessage) throws -> Any
	{
		guard let messageBody = message.body as? String else
		{
			throw RuntimeError("Message body of \(message.name) expected to be string")
		}

		//if message.name == WebxrController.messageName
		if messageBody == "WaitForNextFrame"
		{
			guard let frame = session.currentFrame else
			{
				return "Null frame"
			}

			var frameMeta = [String:Any]()
			frameMeta["Hello"] = 123
			frameMeta["Timestamp"] = frame.timestamp
			frameMeta["DepthTimestamp"] = frame.capturedDepthDataTimestamp
			
			WebxrController.WriteCameraMeta( camera: frame.camera, meta: &frameMeta )
			
			//print( frameMeta["WorldTransform"] ?? "null transform" )
			return frameMeta
		}
		
		print(message.name)
		throw RuntimeError("Unhandled \(message.name)")
	}
	
	//	async
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) 
	{
		do
		{
			let result = try HandleMessage(message)
			replyHandler( result, nil )
		}
		catch 
		{
			replyHandler( nil, error.localizedDescription )
		}
	}
	/*
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) 
	{
		if message.name == JavaScriptAPIObjectName, let messageBody = message.body as? String {
			print(messageBody)
			replyHandler( 2.2, nil ) // first var is success return val, second is err string if error
		}
	}
	 */
}
