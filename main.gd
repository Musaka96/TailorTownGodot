extends Node3D

## Root of the playable scene. Composes the level, player and camera rig, which
## are wired together in main.tscn.
##
## Top-level input (pause / quit) is handled by the GameState autoload, which
## sits above the pausable scene tree. Add cross-scene wiring or level loading
## here as the game grows.
