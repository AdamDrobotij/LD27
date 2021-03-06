package game.service;

import game.component.Grid;
import game.component.TriggerRule;
import openfl.Assets;
import haxe.CallStack;

class MapService
{
	public static var CLEAR:Int = 0;
	public static var UNKNOWN:Int = 1;
	public static var WATER:Int = 2;
	public static var LAND:Int = 3;
	public static var LAVA:Int = 4;
	
	public static var WIDTH:Int = 14;
	public static var HEIGHT:Int = 13;

	public static var xml:Xml;
	public static var clickMessages:Map<String, String>;
	public static var clickResults:Map<String, String>;
	public static var objectAudio:Map<String, String>;
	public static var triggers:Array<TriggerRule>;

	public static var triggerValues:Array<String> = [
		"clear", "unknown", "water", "land", "lava", "steam", "cells", "algae",
		"mineral", "meteor", "fish", "plant", "seed", "tree", "reptile", "rodent",
		"blank", "herbivore", "carnivore", "caveman", "human", "dwelling", "building", "village",
		"factory", "city", "metropolis", "citadel", "victory"
	];

	public static function getTypeFromValue(value:Int): String
	{
		var res:String = triggerValues[value];
		if(res == null)
		{
			trace("Unknown object type:" + value);
			res = "unknown";
		}
		return res;
	}

	public static function getValueFromType(type:String): Int
	{
		if(type == null)
		{
			trace("Cannot getValueFromType null");
			return -1;
		}

		if(type == "any")
		{
			trace("Cannot determine value for 'any' - must be special-cased.");
			return 0;
		}

		var value = game.util.Util.find(triggerValues, type);
		if(value < 0)
		{			
			trace("Unknown value for type:" + type);
		}
		return value;
	}

	public static function makeTerrain(): Grid
	{
		var chanceWater = 0.5;
		var grid = new Grid(WIDTH, HEIGHT);

		// Randomly set up some land/water
		for(x in 0...grid.width)
		for(y in 0...grid.height)
		{
			var value = (Math.random() <= chanceWater ? WATER : LAND);
			grid.set(x, y, value);
		}

		// Smooth out the shapes, eliminating islands and diagonals.
		var grid2 = new Grid(WIDTH, HEIGHT);

		for(x in 0...grid.width)
		for(y in 0...grid.height)
		{
			var matches = 0;
			var value = grid.get(x, y);
			var neighbors = grid.getNeighboringIndeces(grid.indexOf(x,y), true);
			for(neighbor in neighbors)
				if(grid.getIndex(neighbor) == value)
					matches++;

			if(matches == 0)
				value = grid.getIndex(neighbors[0]);

			grid2.set(x, y, value);
		}

		return grid2;
	}

	public static function makeObjects(): Grid
	{
		var grid = new Grid(WIDTH, HEIGHT, LAVA);
		return grid;
	}

	public static function init(): Xml
	{
		var str:String = Assets.getText("xml/rules.xml");
		xml = Xml.parse(str).firstElement();

		clickMessages = new Map();
		clickResults = new Map();
		objectAudio = new Map();
		triggers = new Array<TriggerRule>();

		for(obj in xml.elementsNamed("object"))
		{
			// Load click rules
			var objectType:String = obj.get("type");
			if(objectType == null)
				throw("object is missing a type:" + obj);

			var audio = obj.get("audio");
			if(audio != null)
				objectAudio.set(objectType, audio);

			for(clk in obj.elementsNamed("click"))
			{
				var message = clk.get("message");
				if(message == null)
					throw("Click is missing message:" + clk);
				clickMessages.set(objectType, message);

				var resultType = clk.get("result");
				if(resultType == null)
					throw("Click is missing result:" + clk);
				if(getValueFromType(resultType) < 0)
					throw("ResultType " + resultType + " is invalid:" + clk);
				if(resultType == "water" || resultType == "land")
					throw("ResultType cannot be terrain:" + clk);
				clickResults.set(objectType, resultType);

				// NOTE this will break if you assign multiple clicks to a single object
				// You'll need to refactor this if you want to add conditional clicks
			}

			// Load trigger rules
			for(trg in obj.elementsNamed("trigger"))
			{
				var resultType = trg.get("result");
				var terrainType = trg.get("terrain");
				var neighborType = trg.get("neighbor");
				var message = trg.get("message");
				var audio = trg.get("audio");

				if(resultType == null)
					throw("Empty resultType for " + trg);
				if(getValueFromType(resultType) < 0)
					throw("ResultType " + resultType + " is invalid:" + trg);
				if(message == null)
					throw("Empty message for " + trg);
				if(terrainType == null)
					terrainType = "any";
				if(neighborType == null)
					neighborType = "any";

				var trigger = new TriggerRule(objectType, terrainType, resultType, neighborType, message, audio);

				if(trg.exists("chance"))
					trigger.chance = Std.parseFloat(trg.get("chance"));
				if(trg.exists("max"))
					trigger.max = Std.parseInt(trg.get("max"));
				if(trg.exists("min"))
					trigger.min = Std.parseInt(trg.get("min"));

				triggers.push(trigger);
			}
		}

		return xml;
	}

	public static function getTriggerRules(): Array<TriggerRule>
	{
		return triggers;
	}

	public static function getClickResult(type:String): String
	{
		return clickResults.get(type);
	}

	public static function getClickMessage(type:String): String
	{
		return clickMessages.get(type);
	}

	public static function getAudio(type:String): String
	{
		return objectAudio.get(type);
	}
}