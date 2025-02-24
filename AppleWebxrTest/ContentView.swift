//
//  ContentView.swift
//  AppleWebxrTest
//
//  Created by Graham Reeves on 21/02/2025.
//
import SwiftUI
import WebKit

//	macos -> ios aliases to make things a little cleaner to write
#if canImport(UIKit)
import UIKit
#else//macos
import AppKit
public typealias UIView = NSView
public typealias UIColor = NSColor
public typealias UIRect = NSRect
public typealias UIViewRepresentable = NSViewRepresentable
#endif


let RequestAnimationFramePolyfill = """
var lastTime = 0;
window.requestAnimationFrame = function(callback, element) {
	var now = window.performance.now();
	var nextTime = Math.max(lastTime + 16, now); //First time will execute it immediately but barely noticeable and performance is gained.
	return setTimeout(function() { callback(lastTime = nextTime); }, nextTime - now);
};
window.cancelAnimationFrame = clearTimeout;
"""

let CustomHandlerApiSource = """
async function CallCustomHandler()
{
	const Result = await window.webkit.messageHandlers.AppleXr.postMessage("WaitForNextFrame");
	console.log(Result);
}
//CallCustomHandler()
"""


struct RuntimeError: LocalizedError
{
	let description: String
	
	init(_ description: String) {
		self.description = description
	}
	
	var errorDescription: String? {
		description
	}
}


//	load custom script
//	https://stackoverflow.com/a/58615934/355753



class WebViewController
{
	var enableDebug = true
	var webXr = WebxrController()
	var testUrlHandler = MyURLSchemeHandler()
	var webView : WKWebView!
	
	init()
	{
		self.webView = CreateWebView()
	}
	
	public func LoadUrl(url:String)
	{
		let request = URLRequest(url: URL(string: url)! )
		webView.load(request)
	}
	

	func CreateWebView() -> WKWebView
	{
		let configuration = GetConfiguration()
		let frame = CGRect.zero
		let webView = WKWebView(frame:frame,configuration:configuration)
		
		if enableDebug
		{
			if webView.responds(to: Selector(("setInspectable:"))) 
			{
				webView.perform(Selector(("setInspectable:")), with: true)
			}
		}
		
		return webView
	}

	func GetConfiguration() -> WKWebViewConfiguration
	{
		let configuration = WKWebViewConfiguration()
		
		let WebxrPolyfillUrl = Bundle.main.url(forResource: "WebxrPolyfill", withExtension: "js")!
		let WebxrPolyfillCode = try! String(contentsOf: WebxrPolyfillUrl, encoding: .utf8)
		let webxrPolyfill = WKUserScript(source: WebxrPolyfillCode, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		configuration.userContentController.addUserScript(webxrPolyfill)
		
		let CustomHandlerApi = WKUserScript(source: CustomHandlerApiSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		configuration.userContentController.addUserScript(CustomHandlerApi)
		
		//	only needed for preview, but still doesnt work great
		//let RequestAnimationFramePolyfill = WKUserScript(source: RequestAnimationFramePolyfill, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		//configuration.userContentController.addUserScript(RequestAnimationFramePolyfill)
		
		//	js: window.webkit.messageHandlers.AppleXr.postMessage(messageText);
		configuration.userContentController.addScriptMessageHandler(webXr, contentWorld:.page, name: WebxrController.messageName)

		
		configuration.setURLSchemeHandler(testUrlHandler, forURLScheme: MyURLSchemeHandler.urlScheme )
		
		return configuration
	}
}

//	macos needs "allow outgoing connections (client)" to get wkwebview to display content
struct WebView : UIViewRepresentable
{
	@Binding var webviewController : WebViewController
	
	public typealias UIViewType = WKWebView
	public typealias NSViewType = WKWebView
		
	public func makeUIView(context: Context) -> UIViewType
	{
		return webviewController.webView
	}
	
	public func makeNSView(context: Context) -> NSViewType
	{
		return makeUIView(context: context)
	}
	
	func updateUIView(_ uiView: WKWebView, context: Context)
	{
		//uiView.
	}
	
	func updateNSView(_ nsView: WKWebView, context: Context) 
	{
		updateUIView( nsView, context:context)
	}
}
/*

class ViewController: UIViewController, WKUIDelegate {
	
	var webView: WKWebView!
	
	override func loadView() {
		let webConfiguration = WKWebViewConfiguration()
		webView = WKWebView(frame: .zero, configuration: webConfiguration)
		webView.uiDelegate = self
		view = webView
	}
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let myURL = URL(string:"https://www.apple.com")
		let myRequest = URLRequest(url: myURL!)
		webView.load(myRequest)
	}
}
*/
struct ContentView: View 
{
	//let url = "https://webglsamples.org/blob/blob.html"
	//let url = "https://immersive-web.github.io/webxr-samples/immersive-ar-session.html"
	//@State var url : String = "https://immersive-web.github.io/webxr-samples/immersive-ar-session.html?usePolyfill=0"
	//@State var url : String = "https://immersive-web.github.io/webxr-samples/"
	@State var url : String = "arkit://NopeAnim"
	
	@State var webViewController = WebViewController()

	func OnReload()
	{
		webViewController.LoadUrl(url: url)
	}
	
	func NavigationView() -> some View
	{
		HStack
		{
			Text(self.url)
			Button(action:OnReload)
			{
				Label("Reload", systemImage:"arrow.clockwise.circle.fill")
			}
		}
		.padding(10)
		.background(.blue)
		.foregroundStyle(.white)
	}
	
	var body: some View 
	{
		WebView(webviewController: self.$webViewController)
			//.edgesIgnoringSafeArea(.all)
			.background(.red)
			.overlay(alignment:.topTrailing)
		{
			NavigationView()
		}
		.onAppear()
		{
			OnReload()
		}
	}
}

#Preview {
	ContentView()
}

