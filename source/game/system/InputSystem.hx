package game.system;

import ash.core.Engine;
import ash.core.System;
import ash.core.Node;
import ash.core.Entity;

import com.haxepunk.utils.Key;

import game.service.EntityService;
import game.service.InputService;
import game.service.MapService;
import game.node.ControlNode;
import game.component.Application;
import game.component.Grid;

#if profiler
	import game.service.ProfileService;
#end

#if (development && !flash)
import sys.io.FileOutput;
#end

class InputSystem extends System
{
	public var engine:Engine;
	public var factory:EntityService;

	public function new(engine:Engine, factory:EntityService)
	{
		super();
		this.engine = engine;
		this.factory = factory;
		InputService.init();
	}

	override public function update(_)
	{
		handleProfileControl();
		handleNarrativeControl();
		handleMenuControl();
		handleGameControl();
		handleEndControl();
		InputService.clearLastKey();
	}

	public function handleProfileControl()
	{
		#if profiler 
	 	for(node in engine.getNodeList(ProfileControlNode))
	 	{
	 		if(InputService.lastKey() == Key.P)
	 		{
	 			ProfileService.dump();
	 			ProfileService.reset();
	 			InputService.clearLastKey();
	 		}
	 	}
		#end
	}

	public function handleMenuControl()
	{
		for(node in engine.getNodeList(MenuControlNode))
		{
			if(InputService.clicked)
				factory.getApplication().changeMode(ApplicationMode.NARRATIVE);
		}
	}

	public function handleNarrativeControl()
	{
		for(node in engine.getNodeList(NarrativeControlNode))
		{
			if(InputService.clicked)
				factory.nextNarrativePage();
		}
	}

	public function handleGameControl()
	{
		for(node in engine.getNodeList(GameControlNode))
		{
			if(InputService.clicked)
			{
				var gridEnt = factory.getGridEntity();
				var index = factory.gridTest(gridEnt, InputService.mouseX, InputService.mouseY);
				if(index >= 0)
				{
					var grid:Grid = gridEnt.get(Grid);
					var value = grid.getIndex(index);
					var type = MapService.getTypeFromValue(value);
					var newType:String = MapService.getClickResult(type);
					var newValue = MapService.getValueFromType(newType);
					grid.setIndex(index, newValue);
					grid.changed = true;

					trace("You clicked on:" + type + " becoming:" + 
						newType + " message:" + 
						MapService.getClickMessage(type) + " gridValue:" + value);

				}
				else factory.getApplication().changeMode(ApplicationMode.END);
			}
		}
	}

	public function handleEndControl()
	{
		for(node in engine.getNodeList(EndControlNode))
		{
			if(InputService.clicked)
				factory.getApplication().changeMode(ApplicationMode.MENU);
		}
	}
}