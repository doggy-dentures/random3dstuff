package;

import away3d.animators.nodes.VertexClipNode;
import away3d.tools.utils.Bounds;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import away3d.animators.*;
import away3d.containers.*;
import away3d.controllers.*;
import away3d.debug.*;
import away3d.entities.*;
import away3d.events.*;
import away3d.library.*;
import away3d.library.assets.*;
import away3d.lights.*;
import away3d.loaders.parsers.*;
import away3d.materials.*;
import away3d.materials.lightpickers.*;
import away3d.materials.methods.*;
import away3d.primitives.*;
import away3d.utils.Cast;
import openfl.display.*;
import openfl.events.*;
import openfl.filters.*;
import openfl.geom.*;
import openfl.text.*;
import openfl.ui.*;
import openfl.utils.ByteArray;
import openfl.Assets;
import openfl.Vector;

class ModelThing
{
	private var modelBytes:ByteArray;
	private var modelMaterial:TextureMaterial;

	public var mesh:Mesh;

	public var animationSet:VertexAnimationSet;

	private var scale:Float;
	private var vertexAnimator:VertexAnimator;

	public var modelView:ModelView;

	public var fullyLoaded:Bool = false;

	private var animSpeed:Map<String, Float>;

	public var currentAnim:String = "";

	public var initYaw:Float;
	public var initPitch:Float;
	public var initRoll:Float;

	public var xOffset:Float = 0;
	public var yOffset:Float = 0;
	public var zOffset:Float = 0;

	public var noLoopList:Array<String>;

	public function new(md2Name:String, _modelView:ModelView, _scale:Float = 1, _animSpeed:Map<String, Float> = null, _initYaw:Float = 0, _initPitch:Float = 0,
			_initRoll:Float = 0, alpha:Float = 1.0, _initX:Float = 0, _initY:Float = 0, _initZ:Float = 0, list:Array<String>)
	{
		if (!Assets.exists('assets/models/' + md2Name + '.md2'))
		{
			trace("ERROR: MODEL OF NAME '" + md2Name + "'.md2 CAN'T BE FOUND!");
			return;
		}
		modelView = _modelView;

		modelBytes = Assets.getBytes('assets/models/' + md2Name + '.md2');
		Asset3DLibrary.loadData(modelBytes, null, null, new MD2Parser());
		Asset3DLibrary.addEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetComplete);
		Asset3DLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);

		if (!Assets.exists('assets/models/' + md2Name + '.png'))
		{
			trace("ERROR: TEXTURE OF NAME '" + md2Name + "'.png CAN'T BE FOUND!");
			return;
		}
		modelMaterial = new TextureMaterial(Cast.bitmapTexture('assets/models/' + md2Name + '.png'));
		modelMaterial.lightPicker = modelView.lightPicker;
		modelMaterial.gloss = 30;
		modelMaterial.specular = 1;
		modelMaterial.ambient = 1;
		// modelMaterial.shadowMethod = modelView.shadowMapMethod;
		modelMaterial.alpha = alpha;
		// if (shimmer)
		// {
		// 	var subsurfaceMethod = new SubsurfaceScatteringDiffuseMethod(2048, 2);
		// 	subsurfaceMethod.scatterColor = 0xc925e6;
		// 	subsurfaceMethod.scattering = 10;
		// 	subsurfaceMethod.translucency = 10;
		// 	modelMaterial.diffuseMethod = subsurfaceMethod;
		// }

		scale = _scale;
		if (_animSpeed == null)
			animSpeed = ["default" => 1.0];
		else
			animSpeed = _animSpeed;
		initYaw = _initYaw;
		initPitch = _initPitch;
		initRoll = _initRoll;
		xOffset = _initX;
		yOffset = _initY;
		zOffset = _initZ;
		noLoopList = list;
		modelView.cameraController.panAngle = 90;
		modelView.cameraController.tiltAngle = 0;
	}

	private function onAssetComplete(event:Asset3DEvent):Void
	{
		if (event.asset.assetType == Asset3DType.MESH)
		{
			mesh = cast(event.asset, Mesh);
			mesh.scaleX = scale;
			mesh.scaleY = scale;
			mesh.scaleZ = scale;
			mesh.yaw(initYaw);
			mesh.pitch(initPitch);
			mesh.roll(initRoll);
		}
		else if (event.asset.assetType == Asset3DType.ANIMATION_NODE)
		{
			var node:VertexClipNode = cast(event.asset, VertexClipNode);
			if (noLoopList.contains(node.name))
				node.looping = false;
		}
		else if (event.asset.assetType == Asset3DType.ANIMATION_SET)
		{
			animationSet = cast(event.asset, VertexAnimationSet);
		}
	}

	private function onResourceComplete(event:LoaderEvent):Void
	{
		vertexAnimator = new VertexAnimator(animationSet);
		//vertexAnimator.playbackSpeed = animSpeed["default"];
		mesh.animator = vertexAnimator;

		fullyLoaded = true;
		render(xOffset, yOffset, zOffset);
	}

	public function render(xPos:Float = 0, yPos:Float = 0, zPos:Float = 0):Void
	{
		mesh.y = yPos;
		mesh.x = xPos;
		mesh.z = zPos;
		mesh.castsShadows = false;
		mesh.material = modelMaterial;
		modelView.addModel(mesh);
		modelView.addedModels.push(this);
		playAnim("idle");
	}

	public function playAnim(anim:String = "", force:Bool = false, frame:Int = 0)
	{
		if (fullyLoaded)
		{
			if (animationSet.animationNames.indexOf(anim) != -1)
			{
				if (force || currentAnim != anim)
				{
					var newSpeed:Float = 1.0;
					if (animSpeed.exists(anim))
						newSpeed = animSpeed[anim];
					else
						newSpeed = animSpeed["default"];
					// trace("ya new speed: " + newSpeed);
					vertexAnimator.playbackSpeed = newSpeed;
					vertexAnimator.play(anim, null, frame);
					currentAnim = anim;
				}
			}
			else
				trace("ANIMATION NAME " + anim + " NOT FOUND.");
		}
		else
			trace("MODEL NOT FULLY LOADED. NO ANIMATION WILL PLAY.");
	}

	public function destroy()
	{
		if (mesh != null)
			mesh.disposeWithChildren();
		if (modelBytes != null)
			modelBytes.clear();
		// if (modelMaterial != null)
		// 	modelMaterial.dispose();
		if (animationSet != null)
			animationSet.dispose();
	}

	public function begoneEventListeners()
	{
		Asset3DLibrary.removeEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetComplete);
		Asset3DLibrary.removeEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
	}

	public function addYaw(angle:Float)
	{
		mesh.yaw(angle);
	}

	public function addPitch(angle:Float)
	{
		mesh.pitch(angle);
	}

	public function addRoll(angle:Float)
	{
		mesh.roll(angle);
	}
}
