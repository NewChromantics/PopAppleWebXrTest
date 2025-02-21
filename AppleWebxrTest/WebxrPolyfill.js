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

//	popengine/math
function MatrixInverse4x4(Matrix)
{
	let m = Matrix;
	let r = [];
	
	r[0] = m[5]*m[10]*m[15] - m[5]*m[14]*m[11] - m[6]*m[9]*m[15] + m[6]*m[13]*m[11] + m[7]*m[9]*m[14] - m[7]*m[13]*m[10];
	r[1] = -m[1]*m[10]*m[15] + m[1]*m[14]*m[11] + m[2]*m[9]*m[15] - m[2]*m[13]*m[11] - m[3]*m[9]*m[14] + m[3]*m[13]*m[10];
	r[2] = m[1]*m[6]*m[15] - m[1]*m[14]*m[7] - m[2]*m[5]*m[15] + m[2]*m[13]*m[7] + m[3]*m[5]*m[14] - m[3]*m[13]*m[6];
	r[3] = -m[1]*m[6]*m[11] + m[1]*m[10]*m[7] + m[2]*m[5]*m[11] - m[2]*m[9]*m[7] - m[3]*m[5]*m[10] + m[3]*m[9]*m[6];
	
	r[4] = -m[4]*m[10]*m[15] + m[4]*m[14]*m[11] + m[6]*m[8]*m[15] - m[6]*m[12]*m[11] - m[7]*m[8]*m[14] + m[7]*m[12]*m[10];
	r[5] = m[0]*m[10]*m[15] - m[0]*m[14]*m[11] - m[2]*m[8]*m[15] + m[2]*m[12]*m[11] + m[3]*m[8]*m[14] - m[3]*m[12]*m[10];
	r[6] = -m[0]*m[6]*m[15] + m[0]*m[14]*m[7] + m[2]*m[4]*m[15] - m[2]*m[12]*m[7] - m[3]*m[4]*m[14] + m[3]*m[12]*m[6];
	r[7] = m[0]*m[6]*m[11] - m[0]*m[10]*m[7] - m[2]*m[4]*m[11] + m[2]*m[8]*m[7] + m[3]*m[4]*m[10] - m[3]*m[8]*m[6];
	
	r[8] = m[4]*m[9]*m[15] - m[4]*m[13]*m[11] - m[5]*m[8]*m[15] + m[5]*m[12]*m[11] + m[7]*m[8]*m[13] - m[7]*m[12]*m[9];
	r[9] = -m[0]*m[9]*m[15] + m[0]*m[13]*m[11] + m[1]*m[8]*m[15] - m[1]*m[12]*m[11] - m[3]*m[8]*m[13] + m[3]*m[12]*m[9];
	r[10] = m[0]*m[5]*m[15] - m[0]*m[13]*m[7] - m[1]*m[4]*m[15] + m[1]*m[12]*m[7] + m[3]*m[4]*m[13] - m[3]*m[12]*m[5];
	r[11] = -m[0]*m[5]*m[11] + m[0]*m[9]*m[7] + m[1]*m[4]*m[11] - m[1]*m[8]*m[7] - m[3]*m[4]*m[9] + m[3]*m[8]*m[5];
	
	r[12] = -m[4]*m[9]*m[14] + m[4]*m[13]*m[10] + m[5]*m[8]*m[14] - m[5]*m[12]*m[10] - m[6]*m[8]*m[13] + m[6]*m[12]*m[9];
	r[13] = m[0]*m[9]*m[14] - m[0]*m[13]*m[10] - m[1]*m[8]*m[14] + m[1]*m[12]*m[10] + m[2]*m[8]*m[13] - m[2]*m[12]*m[9];
	r[14] = -m[0]*m[5]*m[14] + m[0]*m[13]*m[6] + m[1]*m[4]*m[14] - m[1]*m[12]*m[6] - m[2]*m[4]*m[13] + m[2]*m[12]*m[5];
	r[15] = m[0]*m[5]*m[10] - m[0]*m[9]*m[6] - m[1]*m[4]*m[10] + m[1]*m[8]*m[6] + m[2]*m[4]*m[9] - m[2]*m[8]*m[5];
	
	let det = m[0]*r[0] + m[1]*r[4] + m[2]*r[8] + m[3]*r[12];
	for ( let i=0;	i<16;	i++ )
		r[i] /= det;
	
	return r;
	
}

//	todo: use https://github.com/immersive-web/webxr-polyfill/tree/ polyfill
//const polyfill = import('https://cdn.jsdelivr.net/npm/webxr-polyfill@latest/build/webxr-polyfill.js')

//	https://developer.mozilla.org/en-US/docs/Web/API/XRViewport
class XRViewport
{
	get x()	{	return 0;	}
	get y()	{	return 0;	}
	get width()	{	return 1400;	}
	get height()	{	return 1400;	}
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
	constructor(Float16=null)
	{
		if ( !Float16 )
			Float16 = this.identity4x4;
		
		this.values = Float16.slice();
		/*
		 let xform = new XRRigidTransform(
		 {},
		 {x: invOrient[0], y: invOrient[1], z: invOrient[2], w: invOrient[3]});
		 this.refSpace = this.baseRefSpace.getOffsetReferenceSpace(xform);
		 xform = new XRRigidTransform({y: -this.viewerHeight});
*/
	}
	
	get identity4x4()	{	return [1,0,0,0,	0,1,0,0,	0,0,1,0,	0,0,0,1];	}
	
	static CreateIdentity()	{	return new XRRigidTransform();	}
	get matrix()	{	return this.values;	}
	get position()	{	return {x:0,y:0,z:0};	}
	get inverse()	{	return new XRRigidTransform( MatrixInverse4x4(this.matrix) );	}
}


//	https://developer.mozilla.org/en-US/docs/Web/API/XRView
class XRView
{
	constructor(WorldTransform,ProjectionMatrix)
	{
		this.ProjectionMatrix = ProjectionMatrix;
		this.WorldTransform = WorldTransform;
	}
	
	get eye()	{	return 'left';	}
	/*
	view ? view.projectionMatrix : null,
	view ? view.transform : null,
	viewport ? viewport : ((layer && view) ? layer.getViewport(view) : null),
	view ? view.eye : 'left'
	 */
	get projectionMatrix()	{	return this.ProjectionMatrix.matrix;	}
	get transform()	{	return this.WorldTransform;	}
}

class XRPose
{
	constructor(WorldTransform,ProjectionMatrix)
	{
		this.ProjectionMatrix = ProjectionMatrix;
		this.WorldTransform = WorldTransform;
	}
	
	get views()	{	return [new XRView(this.WorldTransform,this.ProjectionMatrix)];	}
}

class XRFrame
{
	constructor(session,FrameMeta)
	{
		this.session = session;
		this.FrameMeta = FrameMeta;
	}
	
	GetWorldTransform()
	{
		let Matrix = this.FrameMeta.WorldTransform;
		return new XRRigidTransform(Matrix);
	}
	
	GetProjectionMatrix()
	{
		let Matrix = this.FrameMeta.ProjectionMatrix;
		return new XRRigidTransform(Matrix);
	}
	
	getViewerPose(referenceSpace)
	{
		return new XRPose( this.GetWorldTransform(), this.GetProjectionMatrix() );
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
			await Yield(30);
			const FrameMeta = await window.webkit.messageHandlers.AppleXr.postMessage("WaitForNextFrame");
			if ( typeof FrameMeta != typeof {} )
			{
				console.log(`WaitForNextFrame -> ${FrameMeta}`);
				continue;
			}
			
			this.#PendingFrame = new XRFrame(this,FrameMeta);
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
