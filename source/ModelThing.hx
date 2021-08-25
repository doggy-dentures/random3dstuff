package;

import away3d.animators.nodes.SkeletonClipNode;
import away3d.animators.data.Skeleton;
import away3d.animators.transitions.CrossfadeTransition;
import away3d.tools.commands.Explode;
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

	private var scale:Float;

	// DD: vertex animations (MD2)
	public var animationSet:VertexAnimationSet;

	private var vertexAnimator:VertexAnimator;

	// DD: Skeleton animations (MD5/AWD)
	private var skeletonAnimator:SkeletonAnimator;
	private var animationSetSkeleton:SkeletonAnimationSet;
	private var stateTransition:CrossfadeTransition;
	private var skeleton:Skeleton;
	private var animationMap:Map<String, ByteArray>;

	public var modelType:String;

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

	public function new(type:String, fileName:String, _modelView:ModelView, _scale:Float = 1, _animSpeed:Map<String, Float> = null, _initYaw:Float = 0,
			_initPitch:Float = 0, _initRoll:Float = 0, alpha:Float = 1.0, _initX:Float = 0, _initY:Float = 0, _initZ:Float = 0, list:Array<String>,
			md5Anims:Map<String, String>)
	{
		modelType = type;

		switch (modelType)
		{
			case 'md2':
				if (!Assets.exists('assets/models/' + fileName + '/' + fileName + '.md2'))
				{
					trace("ERROR: MODEL OF NAME '" + fileName + ".md2' CAN'T BE FOUND!");
					return;
				}

				modelBytes = Assets.getBytes('assets/models/' + fileName + '/' + fileName + '.md2');
				Asset3DLibrary.loadData(modelBytes, null, null, new MD2Parser());
				Asset3DLibrary.addEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetComplete);
				Asset3DLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);

				if (!Assets.exists('assets/models/' + fileName + '/' + fileName + '.png'))
				{
					trace("ERROR: TEXTURE OF NAME '" + fileName + "'.png CAN'T BE FOUND!");
					return;
				}
				modelMaterial = new TextureMaterial(Cast.bitmapTexture('assets/models/' + fileName + '/' + fileName + '.png'));

			case 'md5':
				if (!Assets.exists('assets/models/' + fileName + '/' + fileName + '.md5mesh'))
				{
					trace("ERROR: MODEL OF NAME '" + fileName + ".md5mesh' CAN'T BE FOUND!");
					return;
				}
				stateTransition = new CrossfadeTransition(0.15);
				modelBytes = Assets.getBytes('assets/models/' + fileName + '/' + fileName + '.md5mesh');
				animationMap = new Map<String, ByteArray>();
				for (animName in md5Anims.keys())
				{
					if (!Assets.exists('assets/models/' + fileName + '/' + md5Anims[animName] + '.md5anim'))
					{
						trace("ERROR: MD5 ANIMATION OF NAME '" + md5Anims[animName] + ".md5anim' CAN'T BE FOUND!");
						continue;
					}
					animationMap[animName] = Assets.getBytes('assets/models/' + fileName + '/' + md5Anims[animName] + '.md5anim');
				}

				Asset3DLibrary.addEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetCompleteMD5);
				Asset3DLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceCompleteMD5);
				Asset3DLibrary.loadData(modelBytes, null, null, new MD5MeshParser());

				modelMaterial = new TextureMaterial(Cast.bitmapTexture('assets/models/' + fileName + '/' + fileName + '.png'));

			case 'awd':
				if (!Assets.exists('assets/models/' + fileName + '/' + fileName + '.awd'))
				{
					trace("ERROR: MODEL OF NAME '" + fileName + ".awd' CAN'T BE FOUND!");
					return;
				}
				stateTransition = new CrossfadeTransition(0.15);
				modelBytes = Assets.getBytes('assets/models/' + fileName + '/' + fileName + '.awd');

				Asset3DLibrary.enableParser(AWDParser);
				Asset3DLibrary.addEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetCompleteAWD);
				Asset3DLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceCompleteAWD);
				Asset3DLibrary.loadData(modelBytes);

				if (!Assets.exists('assets/models/' + fileName + '/' + fileName + '.png'))
				{
					trace("ERROR: TEXTURE OF NAME '" + fileName + "'.png CAN'T BE FOUND!");
					return;
				}
				modelMaterial = new TextureMaterial(Cast.bitmapTexture('assets/models/' + fileName + '/' + fileName + '.png'));
		}

		modelView = _modelView;

		modelMaterial.lightPicker = modelView.lightPicker;
		modelMaterial.gloss = 30;
		modelMaterial.specularMethod = new CelSpecularMethod();
		modelMaterial.ambient = 1;
		// modelMaterial.shadowMethod = modelView.shadowMapMethod;
		modelMaterial.alpha = alpha;

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
		// vertexAnimator.playbackSpeed = animSpeed["default"];
		mesh.animator = vertexAnimator;

		render(xOffset, yOffset, zOffset);
	}

	private function onAssetCompleteMD5(event:Asset3DEvent):Void
	{
		if (event.asset.assetType == Asset3DType.ANIMATION_NODE)
		{
			var node:SkeletonClipNode = cast(event.asset, SkeletonClipNode);
			var name:String = event.asset.assetNamespace;
			node.name = name;
			animationSetSkeleton.addAnimation(node);
			if (noLoopList.contains(node.name))
				node.looping = false;
		}
		else if (event.asset.assetType == Asset3DType.ANIMATION_SET)
		{
			animationSetSkeleton = cast(event.asset, SkeletonAnimationSet);
			skeletonAnimator = new SkeletonAnimator(animationSetSkeleton, skeleton);
			for (name in animationMap.keys())
				Asset3DLibrary.loadData(animationMap[name], null, name, new MD5AnimParser());
		}
		else if (event.asset.assetType == Asset3DType.SKELETON)
		{
			skeleton = cast(event.asset, Skeleton);
		}
		else if (event.asset.assetType == Asset3DType.MESH)
		{
			mesh = cast(event.asset, Mesh);
			mesh.material = modelMaterial;
			// mesh.castsShadows = true;
			mesh.scaleX = scale;
			mesh.scaleY = scale;
			mesh.scaleZ = scale;
			mesh.yaw(initYaw);
			mesh.pitch(initPitch);
			mesh.roll(initRoll);
		}
	}

	private function onResourceCompleteMD5(event:LoaderEvent):Void
	{
		mesh.animator = skeletonAnimator;
		render(xOffset, yOffset, zOffset);
	}

	private function onAssetCompleteAWD(event:Asset3DEvent):Void
	{
		if (event.asset.assetType == Asset3DType.SKELETON)
		{
			skeleton = cast(event.asset, Skeleton);
			animationSetSkeleton = new SkeletonAnimationSet();
			skeletonAnimator = new SkeletonAnimator(animationSetSkeleton, cast(event.asset, Skeleton), true);
		}
		else if (event.asset.assetType == Asset3DType.ANIMATION_NODE)
		{
			var node:SkeletonClipNode = cast(event.asset, SkeletonClipNode);
			animationSetSkeleton.addAnimation(node);
			if (noLoopList.contains(node.name))
				node.looping = false;
		}
		else if (event.asset.assetType == Asset3DType.MESH)
		{
			mesh = cast(event.asset, Mesh);
			mesh.material = modelMaterial;
			// mesh.castsShadows = true;
			mesh.scaleX = scale;
			mesh.scaleY = scale;
			mesh.scaleZ = scale;
			mesh.yaw(initYaw);
			mesh.pitch(initPitch);
			mesh.roll(initRoll);
		}
	}

	private function onResourceCompleteAWD(event:LoaderEvent):Void
	{
		mesh.animator = skeletonAnimator;
		render(xOffset, yOffset, zOffset);
	}

	public function render(xPos:Float = 0, yPos:Float = 0, zPos:Float = 0):Void
	{
		mesh.y = yPos;
		mesh.x = xPos;
		mesh.z = zPos;
		if (modelType == 'md2')
		{
			mesh.castsShadows = false;
			mesh.material = modelMaterial;
		}
		modelView.addModel(mesh);
		modelView.addedModels.push(this);
		fullyLoaded = true;
		playAnim("idle");
	}

	public function playAnim(anim:String = "", force:Bool = false, offset:Int = 0)
	{
		if (fullyLoaded)
		{
			switch (modelType)
			{
				case 'md2':
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
							vertexAnimator.play(anim, null, offset);
							currentAnim = anim;
						}
					}
					else
						trace("ANIMATION NAME " + anim + " NOT FOUND.");
				case 'md5':
					if (animationSetSkeleton.animationNames.indexOf(anim) != -1)
					{
						if (force || currentAnim != anim)
						{
							var newSpeed:Float = 1.0;
							if (animSpeed.exists(anim))
								newSpeed = animSpeed[anim];
							else
								newSpeed = animSpeed["default"];
							skeletonAnimator.playbackSpeed = newSpeed;
							skeletonAnimator.play(anim, stateTransition, offset);
							currentAnim = anim;
						}
					}
					else
						trace("ANIMATION NAME " + anim + " NOT FOUND.");
				case 'awd':
					if (animationSetSkeleton.animationNames.indexOf(anim) != -1)
					{
						if (force || currentAnim != anim)
						{
							var newSpeed:Float = 1.0;
							if (animSpeed.exists(anim))
								newSpeed = animSpeed[anim];
							else
								newSpeed = animSpeed["default"];
							if (skeletonAnimator == null)
							{
								trace("WTF LAME");
								return;
							}
							skeletonAnimator.playbackSpeed = newSpeed;
							skeletonAnimator.play(anim, stateTransition, offset);
							currentAnim = anim;
						}
					}
					else
						trace("ANIMATION NAME " + anim + " NOT FOUND.");
			}
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
		if (animationSetSkeleton != null)
			animationSetSkeleton.dispose();
		if (skeleton != null)
			skeleton.dispose();
		if (skeletonAnimator != null)
			skeletonAnimator.dispose();
		if (vertexAnimator != null)
			vertexAnimator.dispose();
		stateTransition = null;
		animationMap = null;
	}

	public function begoneEventListeners()
	{
		Asset3DLibrary.removeEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetComplete);
		Asset3DLibrary.removeEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
		Asset3DLibrary.removeEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetCompleteMD5);
		Asset3DLibrary.removeEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceCompleteMD5);
		Asset3DLibrary.removeEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetCompleteAWD);
		Asset3DLibrary.removeEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceCompleteAWD);
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
