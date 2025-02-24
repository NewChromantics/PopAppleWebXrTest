#if canImport(ARKit)
import ARKit
#endif
import WebKit
import PopCommon
import PopCommonObjc



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

	

class WebxrController : NSObject, WKScriptMessageHandlerWithReply, ARSessionDelegate, WKURLSchemeHandler
{
	static let urlScheme = "arkit"
	let cameraStreamUrl = "CameraStream"
	static let messageName : String = "AppleXr"
	var session = ARSession()
	var frameQueue = [ARFrame]()
	var dropFrames = true
	
	override init()
	{
		super.init()
		session.delegate = self
		session.run( ARWorldTrackingConfiguration()/*, options:ARSession.RunOptions */)
	}
	
	func session(_ session: ARSession, didUpdate frame: ARFrame)
	{
		if dropFrames
		{
			frameQueue = []
		}
		frameQueue.append(frame)
		print("New frame (now x\(frameQueue.count))")
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
	
	let bigData = Array(repeating: 0xffffffff, count: 2024*2024 )
	
	
	func popNextFrame() -> ARFrame?
	{
		//	not using buffering
		if session.delegate == nil
		{
			return session.currentFrame
		}
		
		if dropFrames
		{
			let last = frameQueue.last
			frameQueue = []
			return last
		}
		
		return frameQueue.popFirst()
	}
	
	func peekNextFrame() -> ARFrame?
	{
		return frameQueue.last
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
			guard let frame = popNextFrame() else
			{
				return "Null frame"
			}

			var frameMeta = [String:Any]()
			frameMeta["Hello"] = 123
			frameMeta["Timestamp"] = frame.timestamp
			frameMeta["DepthTimestamp"] = frame.capturedDepthDataTimestamp
			
			//	way too slow
			//frameMeta["BigData"] = Array(repeating: 0xffffffff, count: 2024*2024 )
			//frameMeta["BigData"] = bigData
			
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
	
	public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) 
	{
		let request = urlSchemeTask.request
		guard let requestUrl = request.url else { return }
		
		let responseTask = Task.detached(priority: .background)
		{
			//let filePath = requestUrl.absoluteString	// absolute includes scheme
			var filePath = requestUrl.path().suffix(after:"/") ?? requestUrl.path()
			
			do
			{
				print("request for \(filePath)")
				if requestUrl.path() == ""
				{
					try await urlSchemeTask.sendStreamedResourceFile(resourceFilename: "ArkitCameraPage", resourceExtension: "html", mimeType:"text/html")
					return
				}
				
				if filePath == self.cameraStreamUrl
				{
					try await self.sendStreamedCameraImage(urlSchemeTask)
					return
				}

				throw RuntimeError("Unhandled url")
			}
			catch
			{
				print("Failed to open \(filePath); \(error.localizedDescription)")
				let errorResponse = NSError(domain: "Failed to fetch resource",
											code: 0,
											userInfo: nil)
				urlSchemeTask.didFailWithErrorSafe(errorResponse)
			}
		}
	}
	
	public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) 
	{
		print("todo: stop url \(urlSchemeTask.request.url)")
	}
	
	func sendStreamedCameraImage(_ urlSchemeTask:WKURLSchemeTask) async throws
	{
		//	send initial response
		let response = URLResponse(url: urlSchemeTask.request.url!,
								   mimeType: "application/octet-stream",
								   expectedContentLength: 0,
								   textEncodingName: nil)
		try urlSchemeTask.didReceiveSafe(response)
		

		while ( !Task.isCancelled )
		{
			try await Task.sleep(for:.milliseconds(5))
			
			guard let frame = self.popNextFrame() else
			{
				//try await Task.sleep(for:.milliseconds(10))
				continue
			}
			
			let pixels = frame.capturedImage
				/*
			guard let pixels = frame.sceneDepth?.depthMap else
			{
				print("no pixels")
				try await Task.sleep(for:.milliseconds(300))
				continue
			}
			*/
			//	get pixels as bytes
			try pixels.LockPixels()
			{
				bytes in
				let dataBytes = Data(bytes)
				//let dataSlice = dataBytes[0..<1_000]
				let dataSlice = dataBytes
				print("Sending \(dataSlice.count/1024/1024)mb")
				try urlSchemeTask.didReceiveSafe(dataSlice)
			}
		}
		
		try urlSchemeTask.didFinishSafe()
	}
}


extension WKURLSchemeTask
{
	func sendHtml(html:String) throws
	{
		let response = URLResponse(url: self.request.url!,
								   mimeType: "text/html",
								   expectedContentLength: 0,
								   textEncodingName: nil)
		let data = html.data(using: .utf8)!
		try self.didReceiveSafe(response)
		try self.didReceiveSafe(data)
		try self.didFinishSafe()
	}
	
	func sendStreamedResourceFile(resourceFilename:String,resourceExtension:String,mimeType:String) async throws 
	{
		var filePathWithoutExtension = resourceFilename.trimSuffix(".\(resourceExtension)")
		let bundlePath = Bundle.main.path(forResource: filePathWithoutExtension, ofType: resourceExtension) ?? "xxx"
		
		print("Loading \(bundlePath)")
		//if let fileHandle = FileHandle(forReadingAtPath: filePath) 
		guard let fileHandle = FileHandle(forReadingAtPath: bundlePath) else
		{
			throw RuntimeError("Failed to open \(bundlePath)")
		}
		
		// video files can be very large in size, so read them in chuncks.
		let chunkSize = 1 * 1024 * 1024 // 1Mb
		let response = URLResponse(url: self.request.url!,
								   mimeType: mimeType,
								   expectedContentLength: 0,	//	this was the chunk size, but then would corrupt if sent too slow??
								   textEncodingName: nil)
		try self.didReceiveSafe(response)
		
		var TotalBytes = 0
		while ( !Task.isCancelled )
		{
			var data = fileHandle.readData(ofLength: chunkSize) // get the first chunk
			print("chunk \(data.count) bytes")
			if data.isEmpty 
			{
				break
			}
			try self.didReceiveSafe(data)
			TotalBytes += data.count
		}
		print("sent \(TotalBytes) total bytes")
		fileHandle.closeFile()
		try self.didFinishSafe()
	}
	
	func didReceiveSafe(_ response:URLResponse) throws
	{
		try ObjC.tryExecute
		{
			self.didReceive(response)
		}
	}
	
	func didReceiveSafe(_ data:Data) throws
	{
		try ObjC.tryExecute
		{
			self.didReceive(data)
		}
	}
	
	func didFinishSafe() throws
	{
		try ObjC.tryExecute
		{
			self.didFinish()
		}
	}
	
	//	should throw, but not much point as we're already erroring
	func didFailWithErrorSafe(_ error:any Error)
	{
		do
		{
			try ObjC.tryExecute
			{
				self.didFailWithError(error)
			}
		}
		catch
		{
			print("didFailWithError() failed; \(error.localizedDescription)")
		}
	}
			
}

// This is based on "Customized Loading in WKWebView" WWDC video (near the end of the
// video) at https://developer.apple.com/videos/play/wwdc2017/220 and A LOT of trial
// and error to figure out how to push work to background thread.
//
// To better understand how WKURLSchemeTask (and internally WebURLSchemeTask) works
// you can refer to the source code of WebURLSchemeTask at
// https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/WebURLSchemeTask.cpp
//
// Looking at that source code you can see that a call to any of the internals of
// WebURLSchemeTask (which is made through WKURLSchemeTask) is expected to be on the
// main thread, as you can see by the ASSERT(RunLoop::isMain()) statements at the
// beginning of pretty much every function and property getters. I'm not sure why Apple
// has decided to do these on the main thread since that would result in a blocked UI
// thread if we need to return large responses/files. At the very least they should have
// allowed for calls to come back on any thread and internally pass them to the main
// thread so that developers wouldn't have to write thread-synchronization code over and
// over every time they want to use WKURLSchemeHandler.
//
// The solution to pushing things off main thread is rather cumbersome. We need to call
// into DispatchQueue.global(qos: .background).async {...} but also manually ensure that
// everything is synchronized between the main and bg thread. We also manually need to
// keep track of the stopped tasks b/c a WKURLSchemeTask does not have any properties that
// we could query to see if it has stopped. If we respond to a WKURLSchemeTask that has
// stopped then an unmanaged exception is thrown which Swift cannot catch and the entire
// app will crash.
public class MyURLSchemeHandler: NSObject, WKURLSchemeHandler 
{
	static let urlScheme = "resource"
	
	//	todo: turn this into tasks we can cancel
	private var stoppedTaskURLs: [URLRequest] = []
	
	public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
		let request = urlSchemeTask.request
		guard let requestUrl = request.url else { return }
		
		if requestUrl.scheme != MyURLSchemeHandler.urlScheme
		{
			return
		}

		let responseTask = Task.detached(priority: .background)
		{
			//let filePath = requestUrl.absoluteString	// absolute includes scheme
			var filePath = requestUrl.path().suffix(after:"/") ?? requestUrl.path()

			do
			{
				//	return html
				if requestUrl.path() == ""
				{
					let html = "<html><head></head><body><h1>Hello</h1><img src=NopeAnim.mp4 /></body></html>"
					try urlSchemeTask.sendHtml(html: html)
					return
				}
				
				let fileExtension = requestUrl.pathExtension
				try await urlSchemeTask.sendStreamedResourceFile(resourceFilename: filePath, resourceExtension: fileExtension, mimeType: "video/mp4")
			}
			catch
			{
				print("Failed to open \(filePath); \(error.localizedDescription)")
				let errorResponse = NSError(domain: "Failed to fetch resource",
								  code: 0,
								  userInfo: nil)
				urlSchemeTask.didFailWithError(errorResponse)
			}
		}
	}
	
	public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) 
	{
		print("todo: cancel task for \(urlSchemeTask.request.url)")
	}
	
}
