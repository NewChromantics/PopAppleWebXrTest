#if canImport(ARKit)
import ARKit
#endif
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
			
			//	way too slow
			frameMeta["BigData"] = Array(repeating: 0xffffffff, count: 2024*2024 )
			
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
	/*
	func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) 
	{
		let blue = Data([0,0,255,255])
		let bytesPerRow = 4
		let x = 0
		let y = 0
		let width = 1
		let height = 1
		let userInfo : Any? = nil

		urlSchemeTask.request.provideImageData(blue, bytesPerRow: bytesPerRow, origin: x, size: y, userInfo: userInfo )
	}
	
	func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) 
	{
	}
	*/
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
	static let urlScheme = "arkit"
	private var stoppedTaskURLs: [URLRequest] = []
	
	public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
		let request = urlSchemeTask.request
		guard let requestUrl = request.url else { return }
		
		//DispatchQueue.global(qos: .background).async { [weak self] in
		//guard let strongSelf = self, requestUrl.scheme == MyURLSchemeHandler.urlScheme else {
		let strongSelf = self
		guard requestUrl.scheme == MyURLSchemeHandler.urlScheme else {
				return
			}
			
			//let filePath = requestUrl.absoluteString	// absolute includes scheme
			let filePath = requestUrl.host ?? ""
		print("Loading \(filePath)")
			if let fileHandle = FileHandle(forReadingAtPath: filePath) 
			{
				// video files can be very large in size, so read them in chuncks.
				let chunkSize = 1024 * 1024 // 1Mb
				let response = URLResponse(url: requestUrl,
										   mimeType: "video/mp4",
										   expectedContentLength: chunkSize,
										   textEncodingName: nil)
				strongSelf.postResponse(to: urlSchemeTask, response: response)
				var data = fileHandle.readData(ofLength: chunkSize) // get the first chunk
				while (!data.isEmpty && !strongSelf.hasTaskStopped(urlSchemeTask)) {
					strongSelf.postResponse(to: urlSchemeTask, data: data)
					data = fileHandle.readData(ofLength: chunkSize) // get the next chunk
				}
				fileHandle.closeFile()
				strongSelf.postFinished(to: urlSchemeTask)
			} else {
				print("Failed to open \(filePath)")
				strongSelf.postFailed(
					to: urlSchemeTask,
					error: NSError(domain: "Failed to fetch resource",
								   code: 0,
								   userInfo: nil))
			}
			
			// remove the task from the list of stopped tasks (if it is there)
			// since we're done with it anyway
			strongSelf.stoppedTaskURLs = strongSelf.stoppedTaskURLs.filter{$0 != request}
		//}
	}
	
	public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
		if (!self.hasTaskStopped(urlSchemeTask)) {
			self.stoppedTaskURLs.append(urlSchemeTask.request)
		}
	}
	
	private func hasTaskStopped(_ urlSchemeTask: WKURLSchemeTask) -> Bool {
		return self.stoppedTaskURLs.contains{$0 == urlSchemeTask.request}
	}
	
	private func postResponse(to urlSchemeTask: WKURLSchemeTask,  response: URLResponse) {
		post(to: urlSchemeTask, action: {urlSchemeTask.didReceive(response)})
	}
	
	private func postResponse(to urlSchemeTask: WKURLSchemeTask,  data: Data) {
		post(to: urlSchemeTask, action: {urlSchemeTask.didReceive(data)})
	}
	
	private func postFinished(to urlSchemeTask: WKURLSchemeTask) {
		post(to: urlSchemeTask, action: {urlSchemeTask.didFinish()})
	}
	
	private func postFailed(to urlSchemeTask: WKURLSchemeTask, error: NSError) {
		post(to: urlSchemeTask, action: {urlSchemeTask.didFailWithError(error)})
	}
	
	private func post(to urlSchemeTask: WKURLSchemeTask, action: @escaping () -> Void) {
		let group = DispatchGroup()
		group.enter()
		DispatchQueue.main.async { [weak self] in
			if (self?.hasTaskStopped(urlSchemeTask) == false) {
				action()
			}
			group.leave()
		}
		group.wait()
	}
}
