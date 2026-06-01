class_name StickerShapeUtils
extends RefCounted

## Builds sprite-sized collision polygons from imported sticker alpha.

const ALPHA_THRESHOLD := 0.08
const POLYGON_SIMPLIFY := 2.0


static func build_shape(source: Image) -> Dictionary:
	var image := source.duplicate()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var size := Vector2i(image.get_width(), image.get_height())
	return {
		"texture": ImageTexture.create_from_image(image),
		"image": image,
		"polygons": _polygons_from_alpha(image, size),
		"pixel_size": Vector2(size),
	}


static func build_shape_from_texture(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	var image := texture.get_image()
	if image.get_format() != Image.FORMAT_RGBA8:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
	var size := Vector2i(image.get_width(), image.get_height())
	return {
		"texture": texture,
		"image": image,
		"polygons": _polygons_from_alpha(image, size),
		"pixel_size": Vector2(size),
	}


static func scaled_factor(pixel_size: Vector2, max_dimension: float) -> float:
	if pixel_size.x <= 0.0 or pixel_size.y <= 0.0:
		return 1.0
	return max_dimension / maxf(pixel_size.x, pixel_size.y)


static func _polygons_from_alpha(image: Image, size: Vector2i) -> Array[PackedVector2Array]:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, ALPHA_THRESHOLD)
	var raw: Array = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), POLYGON_SIMPLIFY)
	var centered: Array[PackedVector2Array] = []
	var offset := Vector2(size) * -0.5
	for polygon in raw:
		if not polygon is PackedVector2Array:
			continue
		var points := PackedVector2Array()
		for point in polygon:
			points.append(point + offset)
		if points.size() >= 3:
			centered.append(points)
	return centered
