package game.service;

import com.haxepunk.HXP;

import ash.core.Engine;
import ash.core.Entity;
import ash.core.Node;

import game.component.ActionQueue;
import game.component.Alpha;
import game.component.Animation;
import game.component.Application;
import game.component.CameraFocus;
import game.component.Control;
import game.component.Dependents;
import game.component.Display;
import game.component.Emitter;
import game.component.Grid;
import game.component.Image;
import game.component.Layer;
import game.component.Offset;
import game.component.Origin;
import game.component.Position;
import game.component.Radius;
import game.component.Repeating;
import game.component.Rotation;
import game.component.Scale;
import game.component.ScrollFactor;
import game.component.Size;
import game.component.Sound;
import game.component.Subdivision;
import game.component.Text;
import game.component.Tile;
import game.component.Timestamp;
import game.component.Tween;
import game.node.TransitionalNode;
import game.node.CameraFocusNode;
import game.node.SoundNode;
import game.util.Easing;
import game.util.Util;
import game.service.SaveService;

using StringTools;

class DependentsNode extends Node<DependentsNode>
{
	public var dependents:Dependents;
}

class EntityService
{
	public static inline var CONTROL:String = "control";
	public static inline var AUDIO_HALT:String = "audioHalt";
	public static inline var APPLICATION:String = "application";

	public var engine:Engine;
	public var nextId:Int = 0;

	public function new(engine:Engine)
	{
		this.engine = engine;
		engine.getNodeList(DependentsNode).nodeRemoved.add(dependentsNodeRemoved); // entity lifecycle dependency
	}

	public function makeEntity(prefix:String): Entity // does NOT add entity to engine
	{
		var name = prefix + nextId++;
		return new Entity(name);
	}

	public function getApplication(): Application
	{
		var e = resolveEntity(APPLICATION);
		var app = e.get(Application);
		if(app == null)
		{
			app = new Application();
			e.add(app);
			e.add(Transitional.ALWAYS);
		}
		return app;
	}

	// Finds or makes a named entity and adds it to the engine
	public function resolveEntity(name:String): Entity
	{
		var e = engine.getEntityByName(name);
		if(e != null)
			return e;
		return add(new Entity(name));
	}

	public function add(entity:Entity): Entity
	{
		engine.addEntity(entity);
		return entity;
	}

	public function addTo(e:Entity, x:Float, y:Float): Entity
	{
		e.add(new Position(x, y));
		return add(e);
	}

	public function transitionTo(mode:ApplicationMode): Void
	{
		// Remove all entities, excepting those marked as transitional for this mode
		for(e in engine.entities)
		{
			if(e.has(Transitional))
			{
				var transitional:Transitional = e.get(Transitional);
				if(transitional.isProtected(mode))
				{
					if(transitional.destroyComponent)
						e.remove(Transitional);
					else 
						transitional.complete = true;					
					continue;
				}
			}

			engine.removeEntity(e);
		}
	}

	public function removeTransitionedEntities()
	{
		for(node in engine.getNodeList(TransitionalNode))
		{
			if(node.transitional.isCompleted()) // should spare ALWAYS transitionals from removal
				engine.removeEntity(node.entity);
		}
	}

	public function restartApplicationMode(): Void
	{
		var app:Application = getApplication();
		app.init = true;
		// trace("Restarting application mode " + app.mode);
	}

	private function dependentsNodeRemoved(node:DependentsNode): Void
	{
		removeDependents(node.entity);
	}

	// Creates a lifecycle dependency between entities. When the parent entity
	// is destroyed, all of its dependent children will also be immediately destroyed.
	public function addDependent(parent:Entity, child:Entity): Void
	{		
		// trace("Creating dependency. Parent:" + parent.name + " Child:" + child.name);

		if(child == null)
			throw("Cannot create dependency; child entity does not exist");
		if(parent == null)
			throw("Cannot create dependency; parent entity does not exist");

		var dependents = parent.get(Dependents);
		if(dependents == null)
		{
			dependents = new Dependents();
			parent.add(dependents);
		}

		dependents.add(child.name);
	}

	public function addDependentByName(parentName:String, childName:String): Void
	{
		var parent = engine.getEntityByName(parentName);
		var child = engine.getEntityByName(childName);
		addDependent(parent, child);
	}

	// Destroys all dependents of the entity
	public function removeDependents(e:Entity): Void
	{
		var dependents:Dependents = e.get(Dependents);
		if(dependents == null)
			return;

		for(name in dependents.names)
		{
			var e:Entity = engine.getEntityByName(name);
			if(e != null)
			{
				engine.removeEntity(e);
				// trace("Removing dependent:" + e.name);
			}
			// else trace(" ** Can't remove already gone dependent " + name);
		}
		dependents.clear();
	}

	public function markerNameToEntityName(markerName:String): String
	{
		return "marker-" + markerName;
	}

	public function hasMarker(markerName:String): Bool
	{
		var name = markerNameToEntityName(markerName);
		return (engine.getEntityByName(name) != null);
	}

	public function addMarker(markerName:String): Void
	{
		var name = markerNameToEntityName(markerName);
		if(!hasMarker(name))
			resolveEntity(name);
	}

	public function removeMarker(markerName:String): Void
	{
		var name = markerNameToEntityName(markerName);
		var entity = engine.getEntityByName(name);
		if(entity != null)
			engine.removeEntity(entity);
	}

	// Entity hit test, does not currently respect the Scale component
	public function hitTest(e:Entity, x:Float, y:Float): Bool
	{
		if(e == null)
			return false;

		var pos = e.get(Position);
		var image = e.get(Image);
		if(image == null && e.has(Animation))
			image = e.get(Animation).image;
		if(pos == null || image == null)
			return false;

		var off = e.get(Offset);

	trace("Hit Test e:" + e.name	
			+ " x:" + Std.string(x) 
			+ " y:" + Std.string(y)
			+ " pos.x:" + Std.string(pos.x) 
			+ " pos.y:" + Std.string(pos.y)
			+ " off.x:" + Std.string(off.x) 
			+ " off.y:" + Std.string(off.y)
			+ " image.width:" + Std.string(image.width) 
			+ " image.height:" + Std.string(image.height)
		);

		if(off != null)
		{
			x -= off.x;
			y -= off.y;
		}

		return(x >= pos.x && x < (pos.x + image.width) && 
			y >= pos.y && y < (pos.y + image.height));
	}

	public function startInit(): Void
	{
		#if profiler
			ProfileService.init();
			var e = new Entity("profileControl");
			e.add(ProfileControl.instance);
			e.add(Transitional.ALWAYS);
			engine.addEntity(e);
		#end
	}

	public function changeCameraFocus(entity:Entity): Void
	{
		for(node in engine.getNodeList(CameraFocusNode))
			node.entity.remove(CameraFocus);
		entity.add(CameraFocus.instance);			
	}

	public function addActionQueue(name:String = null): ActionQueue
	{
		var e = makeEntity("aq");
		if(name != null)
			e.name = name;

		var aq = new ActionQueue();
		e.add(aq);
		aq.destroyEntity = true;
		add(e);
		aq.name = e.name;

		return aq;
	}

	public function addTween(source:Dynamic, target:Dynamic, duration:Float, 
		easing:EasingFunction = null, optional:Float = 1.70158, name:String = null): Tween
	{
		var e = makeEntity("tween");
		if(name != null)
			e.name = name;

		var tween = new Tween(source, target, duration, easing, optional);
		tween.destroyEntity = true;
		e.add(tween);
		add(e);
		tween.name = e.name;

		return tween;
	}

	public function addControl(control:Control): Entity
	{
		// trace("Adding control " + Type.typeof(control));
		var e = resolveEntity(CONTROL);
		e.add(control);
		return e;
	}

	public function removeControl(control:Class<Control>): Entity
	{
		var e = resolveEntity(CONTROL);
		e.remove(control);
		return e;
	}

	public function hasControl(control:Class<Control>): Bool
	{
		var e = resolveEntity(CONTROL);
		return e.has(control);
	}

	public function stopSounds(): Void
	{
		var ent:Entity = resolveEntity(AUDIO_HALT);
		ent.add(Timestamp.create());
	}

	public function stopSound(file:String): Void
	{
		for(node in engine.getNodeList(SoundNode))
		{
			if(node.sound.file == file)
				node.sound.stop = true;
		}
	}

	public function addSound(name:String, loop:Bool = false, offset:Float = 0): Entity
	{
		return add(getSound(name, loop, offset));
	}

	public function getSound(name:String, loop:Bool = false, offset:Float = 0): Entity
	{
		var e = makeEntity("sound");
		var sound = new Sound(name, loop, offset);
		sound.destroyEntity = true;
		e.add(sound);
		return e;
	}

	// Returns true if the named entity exists in the engine, otherwise false
	public function entityExists(name:String): Bool
	{
		return (engine.getEntityByName(name) != null);
	}
	
	public function getEntity(name:String): Entity
	{
		return name == null ? null : engine.getEntityByName(name);
	}

	public function getComponent<T>(name:String, component:Class<T>): T
	{
		var e:Entity = getEntity(name);
		if(e == null)
			return null;
		return e.get(component);
	}

	public function removeEntity(name:String): Void
	{
		var e:Entity = getEntity(name);
		if(e != null)
			engine.removeEntity(e);
	}

	public function countNodes<T:Node<T>>(nodeClass:Class<T>): Int
	{
		var count:Int = 0;
	 	for(node in engine.getNodeList(nodeClass))
	 		count++;
	 	return count;
	}

	/*************************************************************************************/


	public function startMenu(): Void
	{
		startNarrative();
	}

	public function startGame(): Void
	{
		
	}

	public function startEnd(): Void
	{
		
	}

	public function startNarrative(): Void
	{
		var e = makeEntity("bg");
		e.add(Layer.back);
		e.add(new Image("art/altbg.png"));
		addTo(e, 0,0);

		e = makeEntity("button");
		e.add(Layer.middle);
		e.add(new Image("art/but-continue.png"));
		addTo(e, 462, 542);

		e = resolveEntity("narrative_text");
		e.add(Layer.middle);
		var style = new TextStyle(0xFFFFFF, 30, "font/SnappyServiceNF.ttf");
		e.add(new Offset(0,0));
		e.add(new Text("??", style));
		e.add(new Position(21, 67));

		addControl(new NarrativeControl());

		nextNarrativePage();
	}

	public function nextNarrativePage(): Void
	{
		var e = resolveEntity(CONTROL);
		var control:NarrativeControl = e.get(NarrativeControl);
		control.page++;

		var str = "Unknown page.";
		switch(control.page)
		{
			case 1:
			str =
			"Time gave birth to many children called epochs.\n" +  
			"One of these is your ancestor.\n" + 
			"My father - your grandfather - is the hour, \n" + 
			"and he sired your fifty-nine uncles.\n" + 
			"And now I am ready for parenthood.\n" + 
			"You will be my seconds and I \n" + 
			"have great things planned for you.\n" + 
			"Oh but sixty children is way too many!\n" + 
			"You shall number six and you shall span \n" + 
			"ten seconds apiece.";	

			case 2:
			str = 
			"Children, it is time for a world to come to be.\n" + 
			"Each of you must choose where to spend time.\n" + 
			"Where should you speed change and growth?\n" + 
			"First cool the lava to make water and land,\n" + 
			"and also cool the water to make life possible.\n" + 
			"Then hasten hurl a meteor to create minerals.\n" + 
			"Upon the water you may then create life!\n" +
			"And then ... oh, you’ll figure out the rest.";
			
			case 3:
			str = 
			"But know you are not done until\n" + 
			"life on this planet reaches the stars!";

			case 4:
			getApplication().changeMode(ApplicationMode.GAME);
			return;
		}

		e = resolveEntity("narrative_text");
		var text:Text = e.get(Text);
		text.message = str;
	}
}