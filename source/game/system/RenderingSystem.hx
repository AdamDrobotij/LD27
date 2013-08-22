package game.system;

import ash.core.Engine;
import ash.core.System;
import ash.core.Node;

import com.haxepunk.HXP;

import game.render.ImageView;
import game.render.AnimationView;
import game.render.BackdropView;
import game.render.GridView;
import game.render.TextView;
import game.render.EmitterView;
import game.render.View;

import game.node.ViewNode;
import game.node.DisplayNode;

import game.component.Display;

class RenderingSystem extends System
{
	public var engine:Engine;

	public function new(engine:Engine)
	{
		super();
		this.engine = engine;
		engine.getNodeList(DisplayNode).nodeRemoved.add(displayNodeRemoved);
		// engine.getNodeList(TextNode).nodeAdded.add(function(node:TextNode)
		// {
		// 	trace("Adding " + node.entity.name + " to engine!");
		// });
	}

	private function displayNodeRemoved(node:DisplayNode): Void
	{
		// trace("Removing a display node for entity " + node.entity.name);
		HXP.scene.remove(node.display.view);
	}

	// TO DO respond to move events
	override public function update(_)
	{
		updateViews(BackdropNode, BackdropView);
		updateViews(GridNode, GridView);
		updateViews(ImageNode, ImageView);
		updateViews(AnimationNode, AnimationView);
		updateViews(TextNode, TextView);
		updateViews(EmitterNode, EmitterView);
	}

	private function updateViews<TNode:Node<TNode>>(nodeClass:Class<TNode>, viewClass:Class<View>)
	{
		// Loop through all nodes for this node class
	 	for(node in engine.getNodeList(nodeClass))
	 	{
	 		var entity = node.entity;

			// Create view if it does not exist
			var display:Display;
	 		if(!entity.has(Display))
	 		{
	 			var view:View = Type.createInstance(viewClass, [entity]);
				HXP.scene.add(view);
				display = new Display(view);
				entity.add(display);
				// trace("Adding a display node to entity " + entity.name);
	 		}
	 		else display = entity.get(Display);

	 		// Update the view
	 		display.view.nodeUpdate();

	 		// Damn view blew up the whole entity!
	 		if(display.destroyEntity)
	 			engine.removeEntity(entity);
		}
	}	
}