# Tile Spawner

Tile Spawner lets you spawn node instances from a TileMap. Manually placing hundreds of assets is slow and error-prone. TileMaps are easy to add, remove, and manipulate tiles. Tile Spawner is a node that lets you map tiles from a TileSet to scenes in your project and preprocess a TileMap into Node instances as if you had placed them yourself.

Godot can get sluggish when placing lots of instances. Baking ahead-of-time allows you to pay that cost once instead of each time a user launches your scene.

# How to use

To use Tile Spawner, create a JSON mapping between the tiles in your TileMap and scene paths in your project. Then point a Tile Spawner node to a TileMap and bake. See below for further details.

## TileSet

You need a tileset to represent the things you want to spawn. Usually these things are objects and enemies in your game, but can be anything you need that is more complicated than a Sprite + StaticBody + NavigationMesh (which is all that is offered by a TileMap).

The tiles should be named well so that they'll be easy to reference in the mapping json.

## Mapping file

Create a JSON file e.g.

```
{
    "Coin": {
         "scene": "res://objects/coin.tscn"
    },
    "Bricks": {
         "scene": "res://objects/bricks.tscn"
    },
    "Turtle": {
         "scene": "res://enemies/turtle.tscn"
    }
}
```

The keys are the *name of the tile in the TileSet* and the value under the `scene` key is the resource path to the scene that Tile Spawner will intance when spawning.

## TileMap

In your scene, add a TileMap node using the tileset created and mapped above. Paint some tiles.

## TileSpawner

In your scene, add a TileSpawner node. Do not add it as a child of the TileMap. Select the TileSpawner and change the following properties:

* Assign the "Source Tilemap" to the above created TileMap.
* Set the mapping to the above created mapping json file.
* Press the `Bake tiles to nodes` on the control bar.

From here you can repeatedly modify the TileMap and bake.

# TileSpawner properties

## Source Tilemap

Set this to the TileMap node that you want to spawn nodes from.

## Mapping

Set this to a JSON file that describes which tiles spawn which scenes. See the above tutorial for the required format.

## Clear Children Before Baking

If set, the TileSpawner will clear its children before spawning nodes from a tilemap. Generally this is something you'll want to leave enabled as it makes it easier to quickly adjust the tilemap then bake multiple times.

## Spawn at Runtime

If set, the TileSpawner will bake the nodes when the scene loads. Since baking takes a significant amount of time if the number of nodes is large enough, you should only use this while rapidly editing a TileMap.

Don't ship with this checked; instead bake the nodes with the `Bake tiles to nodes` button in the control bar.

## Target Node

By default, nodes are spawned as children of the TileSpawner. This allows you to change where the nodes will spawn instead.

## Grid Alignment

In some cases where pixel-perfection matters and you have odd tile sizes, you might need to snap the spawned object coordinates to whole numbers.

* `None` will not modify the coordinates
* `Round` will round the coordinates to the nearest whole number
* `Floor` will round the coordinates down to the nearest whole number
* `Up` will round the coordinates up to the nearest whole number
* `Trunacte` will remove anything past the decimal point in the coordinates
