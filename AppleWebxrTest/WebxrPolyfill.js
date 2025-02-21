function CreatePromise()
{
	let Callbacks = {};
	let PromiseHandler = function(Resolve,Reject)
	{
		Callbacks.Resolve = Resolve;
		Callbacks.Reject = Reject;
	}
	let Prom = new Promise(PromiseHandler);
	Prom.Resolve = Callbacks.Resolve;
	Prom.Reject = Callbacks.Reject;
	return Prom;
}

function Yield(Milliseconds)
{
	const Promise = CreatePromise();
	setTimeout( Promise.Resolve, Milliseconds );
	return Promise;
}

//	todo: use https://github.com/immersive-web/webxr-polyfill/tree/ polyfill
//const polyfill = import('https://cdn.jsdelivr.net/npm/webxr-polyfill@latest/build/webxr-polyfill.js')

//	https://developer.mozilla.org/en-US/docs/Web/API/XRViewport
class XRViewport
{
	get x()	{	return 0;	}
	get y()	{	return 0;	}
	get width()	{	return 400;	}
	get height()	{	return 400;	}
}

class XRWebGLLayer
{
	constructor(session,glcontext)
	{
		console.log("XRWebGLLayer");
	}
	
	getViewport(view/*XRView*/)
	{
		return new XRViewport();
	}
	
	//	null == inline framebuffer
	get framebuffer()	{	return null;	}
}

class XRRigidTransform
{
	constructor()
	{
		/*
		 let xform = new XRRigidTransform(
		 {},
		 {x: invOrient[0], y: invOrient[1], z: invOrient[2], w: invOrient[3]});
		 this.refSpace = this.baseRefSpace.getOffsetReferenceSpace(xform);
		 xform = new XRRigidTransform({y: -this.viewerHeight});
*/
	}
	
	static CreateIdentity()	{	return new XRRigidTransform();	}
	get matrix()	{	return [1,0,0,0,	0,1,0,0,	0,0,1,0,	0,0,0,1];	}
	get position()	{	return {x:0,y:0,z:0};	}
	get inverse()	{	return new XRRigidTransform();	}
}


//	https://developer.mozilla.org/en-US/docs/Web/API/XRView
class XRView
{
	get eye()	{	return 'left';	}
	/*
	view ? view.projectionMatrix : null,
	view ? view.transform : null,
	viewport ? viewport : ((layer && view) ? layer.getViewport(view) : null),
	view ? view.eye : 'left'
	 */
	get projectionMatrix()	{	return [1,0,0,0,	0,1,0,0,	0,0,1,0,	0,0,0,1];	}
	get transform()	{	return XRRigidTransform.CreateIdentity();	}
}

class XRPose
{
	get views()	{	return [new XRView()];	}
}

class XRFrame
{
	constructor(session)
	{
		this.session = session;
	}
	
	getViewerPose(referenceSpace)
	{
		return new XRPose();
	}
}


const ReferenceSpaceType =
{
	local: "Local",
	viewer: "Viewer"
};

class ReferenceSpaceInstance
{
	//xrImmersiveRefSpace.addEventListener('reset', (evt) => {
	//xrImmersiveRefSpace = xrImmersiveRefSpace.getOffsetReferenceSpace(evt.transform);
	//	https://developer.mozilla.org/en-US/docs/Web/API/XRReferenceSpace/getOffsetReferenceSpace
	getOffsetReferenceSpace(Transform)
	{
		return new ReferenceSpaceInstance();
	}
}

class ArSession
{
	#EventCallbacks = {};
	
	//	immersive = see through
	#IsImmersive = false;
	
	#RenderState = null;
	#IsRunning = true;
	#PendingFrame = null;	//	XRFrame
	
	constructor()
	{
		this.#Thread().catch( this.#OnError.bind(this) );
	}
	
	#OnError(Error)
	{
		console.error(Error);
	}
	
	async #Thread()
	{
		while ( this.#IsRunning )
		{
			const Result = await window.webkit.messageHandlers.AppleXr.postMessage("WaitForNextFrame");
			console.log(Result);
			this.#PendingFrame = new XRFrame(this);
			//	throttle
			await Yield(30);
		}
	}
	
	#PopFrame()
	{
		const Frame = this.#PendingFrame;
		this.#PendingFrame = null;
		return Frame;
	}
	
	
	get isImmersive()		{	return this.#IsImmersive == true;	}
	set isImmersive(value)	{	}//this.#IsImmersive = value;	}

	get renderState()		{	return this.#RenderState;	}
	
	//	user ended session
	end()
	{
		//console.log("User ended session");
	}
	
	addEventListener(eventName,Callback)
	{
		this.#EventCallbacks[eventName] = Callback;
	}
	
	updateRenderState(renderState)
	{
		this.#RenderState= renderState;
		const baseLayer = renderState.baseLayer;
		//{ baseLayer: new XRWebGLLayer(session, gl) });
	}
	
	async requestReferenceSpace(referenceSpaceType)
	{
		return new ReferenceSpaceInstance();
	}
	
	requestAnimationFrame(onXRFrame)
	{
		async function SendNextFrame()
		{
			for ( let i=0;	i<1000;	i++ )
			{
				const Time = 1000;
				const NextFrame = this.#PopFrame();
				if ( NextFrame )
				{
					onXRFrame( Time, NextFrame );
					return;
				}
				await Yield(10);
			}
		}
		
		SendNextFrame.call(this);
		/*
		function Tick()
		{
			const Frame = new XRFrame(this);
			onXRFrame( Time, Frame );
		}
		
		setTimeout( Tick.bind(this), 100 );
		 */
	}
	/*
	OnReset()
	{
		let ResetEvent = {};	//.transform
		this.#EventCallbacks.reset?(ResetEvent);
		
	}
	*/
}




const SessionClasses = 
{
	'inline': ArSession,
	'immersive-ar': ArSession
};


class XrPolyfill
{
	#ActiveSession = null;
	
	FreeSession()
	{
		this.#ActiveSession?.end();
		this.#ActiveSession = null;
	}
	
	async isSessionSupported(sessionType)
	{
		const SessionClass = SessionClasses[sessionType];
		return SessionClass != undefined;
	}
	
	async requestSession(sessionType)
	{
		const SessionClass = SessionClasses[sessionType];
		if ( !SessionClass )
			//throw new NotSupportedError();
			throw `No such session type for ${sessionType}`;
		this.#ActiveSession = new SessionClass();
		return this.#ActiveSession;
	}
}

navigator.xr = new XrPolyfill();
