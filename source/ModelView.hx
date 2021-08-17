package;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
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

class ModelView
{
	//DD: Engine vars
	public var view:View3D;
	public var cameraController:HoverController;
	private var _lookAtPosition:Vector3D = new Vector3D();
	
	// #if debug
	// //DD: Stat tracking
	// private var stats:AwayStats;
	// #end

	//DD: Light objects
	private var light:DirectionalLight;

	public var lightPicker:StaticLightPicker;
	public var shadowMapMethod:FilteredShadowMapMethod;

	//DD: The Flixel objects the engine will use
	private var bmd:BitmapData;
	public var sprite:FlxSprite = new FlxSprite();
	
	//DD: Track models added if we want to remove them later
	public var addedModels:Array<ModelThing> = [];

	public function new()
	{
		//DD: Setup 3d viewing object thing
		view = new View3D();
		//DD: Small resolution cause this is all inefficient and laggy
		//view.width = FlxG.stage.stageWidth/2;
		//view.height = FlxG.stage.stageHeight/2;
		view.width = 450;
		view.height = 450;
		
		FlxG.addChildBelowMouse(view);

		view.camera.lens.far = 5000;
		cameraController = new HoverController(view.camera, null, 90, 0, 300);
		cameraController.lookAtPosition = _lookAtPosition;

		light = new DirectionalLight(-0.5, -1, -1);
		light.ambient = 0.4;
		lightPicker = new StaticLightPicker([light]);
		view.scene.addChild(light);

		shadowMapMethod = new FilteredShadowMapMethod(light);

		// #if debug
		// FlxG.addChildBelowMouse(stats = new AwayStats(view));
		// #end

		bmd = new BitmapData(Std.int(view.width), Std.int(view.height), true, 0x0);
		sprite.loadGraphic(bmd);

	}

	public function update()
	{
		// DD: Time to turn the whole 3D View into a 2D FlxSprite
		// Why? Well, 3D in OpenFL is ALWAYS rendered below the 2D stuff
		// i.e. 3D stuff is never visible if 2D stuff is there too
		// So we gotta turn the 3D into 2D for it to actually show up

		//DD: We gotta set the alpha to 0 then back to 1 for some reason or else transparency doesn't work
		view.backgroundAlpha = 0;
		view.renderer.queueSnapshot(bmd);
		view.render();
		view.backgroundAlpha = 1;

		sprite.loadGraphic(bmd);
		sprite.graphic.persist = true;
	}

	public function addModel(model:Mesh)
	{
		view.scene.addChild(model);
	}

	public function clear()
	{
		for (i in 0...view.scene.numChildren)
		{
			if (view.scene.getChildAt(i) != null)
				view.scene.removeChildAt(i);
		}
	}
}