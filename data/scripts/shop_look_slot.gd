class_name ShopLookSlot
extends Resource

## One recoloured surface in a ShopLook (wall, wainscot, floor, rug or drape): a texture
## set plus the knobs ShopLookApplier turns into a shared StandardMaterial3D. Leave the
## textures empty for a flat-tinted material.

@export var albedo_texture: Texture2D
@export var normal_texture: Texture2D
@export var roughness_texture: Texture2D
## Multiplies the albedo texture (or is the flat colour with none set). Tinted sets
## (bright greyscale textures) get their whole colour from this.
@export var tint: Color = Color.WHITE
## Extra tiling on top of the mesh's baked UV (1.0 = use the bake as-is). See the slot/UV
## table in docs/SHOP_LOOKS.md — e.g. a texture authored at 1 m/tile on a 2 m-baked
## surface needs 2.0 here. ShopLookApplier always forces this to 1.0 for the rug slot,
## whose UVs already span the whole (non-tiling) rug image.
@export_range(0.1, 8.0, 0.05) var uv_scale: float = 1.0
## Roughness multiplier (StandardMaterial3D.roughness): scales the roughness texture, or
## is the flat roughness with none set.
@export_range(0.0, 1.0, 0.01) var roughness: float = 1.0
@export_range(-4.0, 4.0, 0.05) var normal_scale: float = 1.0
