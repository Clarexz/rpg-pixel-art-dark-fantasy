class_name CombatStyle
extends RefCounted
## Estilo visual del combate: paralelogramos inclinados, bordes oscuros y
## tipografía de título. Solo helpers estáticos, sin nodos, para reutilizarlos
## en las pantallas de combate.

## Inclinación única de todas las formas (valor absoluto de StyleBoxFlat.skew.x).
## Para la mano derecha la parte de arriba se va hacia el centro (skew negativo,
## el borde queda "\" y la pila sube en diagonal hacia adentro). En zurdo se espeja.
const SKEW: float = 0.3

const ATTACK: Color = Color(0.77, 0.16, 0.17)
const SPELL: Color = Color(0.42, 0.35, 0.8)
const ITEMS: Color = Color(0.59, 0.43, 0.24)
const FLEE: Color = Color(0.27, 0.27, 0.31)
const NEUTRAL: Color = Color(0.27, 0.27, 0.31)
const GUARD: Color = Color(0.27, 0.38, 0.59)
const PANEL: Color = Color(0.08, 0.055, 0.1, 0.92)
const OUTLINE: Color = Color(0.04, 0.024, 0.047)

const FONT_PATH: String = "res://assets/ui/fonts/Cinzel-Bold.ttf"

static var _title_font: Font


## Tipografía de título (Cinzel Bold), se carga una sola vez.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(FONT_PATH) as Font
	return _title_font


## Inclinación según la mano: zurdo = espejo.
static func skew_for(left_handed: bool) -> float:
	return SKEW if left_handed else -SKEW


## Caja sin esquinas redondeadas, borde de 4 px, inclinada y con sombra suave.
static func skewed_box(color: Color, skew: float = SKEW) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(0)
	s.set_border_width_all(4)
	s.border_color = OUTLINE
	s.skew = Vector2(skew, 0.0)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 4
	s.shadow_offset = Vector2(4, 4)
	return s


## Aplica el estilo inclinado a un botón: normal / hover / pressed / disabled.
static func style_button(b: Button, color: Color, font_size: int, title: bool, skew: float = SKEW) -> void:
	b.add_theme_stylebox_override("normal", skewed_box(color, skew))
	b.add_theme_stylebox_override("hover", skewed_box(color, skew))
	b.add_theme_stylebox_override("pressed", skewed_box(color.lightened(0.35), skew))
	var dim: Color = color.darkened(0.65)
	dim.s *= 0.4
	b.add_theme_stylebox_override("disabled", skewed_box(dim, skew))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", 4)
	if title:
		b.add_theme_font_override("font", title_font())


## Etiqueta con la tipografía de título y contorno oscuro.
static func style_title_label(l: Label, font_size: int, outline: int = 6) -> void:
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
