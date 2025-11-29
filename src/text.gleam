import gleam/int
import gleam/list
import gleam/string
import gleam_community/colour.{type Colour}
import gleam_community/maths
import paint.{type Picture} as p
import values

/// Renders text whose every letter softly oscillates and rotates.
pub fn view_wobbly_text(
  text: String,
  current_time current_time: Float,
  color color: Colour,
) -> Picture {
  string.split(text, on: "")
  |> list.index_map(fn(char, i) {
    view_wobbly_letter(
      char,
      current_time: current_time +. { int.to_float(i) *. 8000.0 },
      color:,
    )
    |> p.translate_x(
      int.to_float(i) *. { values.char_width +. values.char_spacing },
    )
  })
  |> p.combine
}

/// Renders one letter that softly oscillates and rotates.
pub fn view_wobbly_letter(
  letter: String,
  current_time current_time: Float,
  color color: Colour,
) -> Picture {
  let rotation = maths.sin(current_time /. 400.0) *. 0.1
  let y_translation = maths.sin(current_time /. 1600.0) *. 6.0

  view_letter(letter, color)
  |> p.fill(color)
  |> p.stroke_none
  |> p.translate_xy(-6.0, -6.0)
  |> p.rotate(p.angle_rad(rotation))
  |> p.translate_xy(6.0, 6.0 +. y_translation)
}

/// Letter drawn on a 12×12 grid (some features pop out from the top and
/// bottom), with origin on the top-left.
pub fn view_letter(letter: String, color: Colour) -> Picture {
  // In most cases, stroke follows a clockwise motion.
  case letter {
    "a" ->
      p.lines([
        // Top-left.
        #(3.0, 1.0),
        #(11.0, 1.0),
        // Bottom-right.
        #(11.0, 11.0),
        #(1.0, 11.0),
        // Mid-left.
        #(1.0, 5.0),
        #(11.0, 5.0),
      ])

    "b" ->
      p.lines([
        // Top-left, going right.
        #(1.0, 3.0),
        #(11.0, 3.0),
        // Bottom-left.
        #(11.0, 11.0),
        #(1.0, 11.0),
        #(1.0, -1.0),
      ])

    "c" ->
      p.lines([
        // Bottom-right.
        #(11.0, 11.0),
        #(1.0, 11.0),
        // Top-left.
        #(1.0, 1.0),
        #(11.0, 1.0),
        #(11.0, 3.0),
      ])

    "d" ->
      view_letter("b", color)
      |> p.scale_x(-1.0)
      |> p.translate_x(12.0)

    "e" ->
      p.lines([
        // Bottom-right.
        #(9.0, 11.0),
        #(1.0, 11.0),
        // Top-left.
        #(1.0, 1.0),
        #(11.0, 1.0),
        // Mid-right.
        #(11.0, 7.0),
        #(1.0, 7.0),
      ])

    "f" ->
      p.combine([
        // Cross-stroke.
        p.lines([
          #(0.0, 5.0),
          #(11.0, 5.0),
        ]),
        // Stem.
        p.lines([
          // Bottom.
          #(5.0, 12.0),
          #(5.0, -1.0),
          #(12.0, -1.0),
        ]),
      ])

    "g" ->
      p.combine([
        // Top.
        p.lines([
          // Top-left.
          #(0.0, 1.0),
          #(10.0, 1.0),
          // Mid-right.
          #(10.0, 7.0),
          #(1.0, 7.0),
          #(1.0, 1.0),
        ]),
        // Bottom.
        p.lines([
          // Mid-left.
          #(3.0, 7.0),
          #(3.0, 11.0),
          #(11.0, 11.0),
          #(11.0, 13.0),
        ]),
      ])

    "i" ->
      p.combine([
        // Dot.
        p.lines([
          #(6.0, -2.0),
          #(6.0, 0.0),
        ]),
        // Stem.
        p.lines([
          // Top-left.
          #(2.0, 3.0),
          #(6.0, 3.0),
          #(6.0, 11.0),
        ]),
        // Bottom serif.
        p.lines([
          #(0.0, 11.0),
          #(12.0, 11.0),
        ]),
      ])

    "j" ->
      p.combine([
        // Dot.
        p.lines([
          #(11.0, -2.0),
          #(11.0, 0.0),
        ]),
        // Body.
        p.lines([
          // Top-right.
          #(11.0, 2.0),
          #(11.0, 11.0),
          #(1.0, 11.0),
          #(1.0, 9.0),
        ]),
      ])

    "k" ->
      p.combine([
        // Stem.
        p.lines([
          #(1.0, 0.0),
          #(1.0, 12.0),
        ]),
        // Low knee.
        p.lines([
          // Mid-left.
          #(1.0, 6.0),
          #(11.0, 6.0),
          #(11.0, 12.0),
        ]),
        // High shoulder.
        p.lines([
          #(11.0, 0.0),
          #(11.0, 1.0),
          #(6.0, 6.0),
          #(5.0, 6.0),
        ]),
      ])

    "l" ->
      p.lines([
        // Bottom-right.
        #(12.0, 11.0),
        #(1.0, 11.0),
        #(1.0, 0.0),
      ])

    "m" ->
      p.combine([
        // Half-square going around.
        p.lines([
          // Bottom-left.
          #(1.0, 12.0),
          #(1.0, 1.0),
          // Top-right.
          #(11.0, 1.0),
          #(11.0, 12.0),
        ]),
        // Middle stroke.
        p.lines([
          #(6.0, 1.0),
          #(6.0, 12.0),
        ]),
      ])

    "n" ->
      p.lines([
        // Bottom-left.
        #(1.0, 12.0),
        #(1.0, 1.0),
        // Top-right.
        #(9.0, 1.0),
        #(9.0, 3.0),
        #(11.0, 3.0),
        #(11.0, 12.0),
      ])

    "o" ->
      p.lines([
        // Top-left, going right.
        #(0.0, 1.0),
        #(11.0, 1.0),
        #(11.0, 11.0),
        #(1.0, 11.0),
        #(1.0, 1.0),
      ])

    "r" ->
      p.lines([
        // Bottom-left.
        #(1.0, 12.0),
        #(1.0, 1.0),
        #(11.0, 1.0),
        #(11.0, 3.0),
      ])

    "s" ->
      p.lines([
        // Top-right.
        #(11.0, 1.0),
        #(2.0, 1.0),
        // Mid-left.
        #(2.0, 6.0),
        #(11.0, 6.0),
        // Bottom-right.
        #(11.0, 11.0),
        #(1.0, 11.0),
        #(1.0, 9.0),
      ])

    "t" ->
      p.combine([
        // Cross-stroke.
        p.lines([
          #(0.0, 2.0),
          #(12.0, 2.0),
        ]),
        // Stem.
        p.lines([
          // Top-left.
          #(5.0, -1.0),
          #(5.0, 11.0),
          #(12.0, 11.0),
        ]),
      ])

    "u" ->
      p.lines([
        // Top-right.
        #(11.0, 0.0),
        #(11.0, 11.0),
        #(1.0, 11.0),
        #(1.0, 0.0),
      ])

    "v" ->
      p.lines([
        // Top-right.
        #(11.0, 0.0),
        #(11.0, 11.0),
        // Bottom-left (entering corner).
        #(4.0, 11.0),
        #(1.0, 8.0),
        #(1.0, 0.0),
      ])

    "y" ->
      p.combine([
        // Right stroke.
        p.lines([
          // Top-right.
          #(11.0, 0.0),
          #(11.0, 13.0),
          #(1.0, 13.0),
        ]),
        // Left stroke.
        p.lines([
          // Mid-right.
          #(11.0, 9.0),
          #(1.0, 9.0),
          #(1.0, 0.0),
        ]),
      ])

    "0" ->
      p.combine([
        // Around.
        p.lines([
          // Top-left, going right.
          #(0.0, 1.0),
          #(11.0, 1.0),
          #(11.0, 11.0),
          #(1.0, 11.0),
          #(1.0, 1.0),
        ]),
        // Dot.
        p.lines([
          #(5.0, 6.0),
          #(7.0, 6.0),
        ]),
      ])

    "1" ->
      p.combine([
        // Stem.
        p.lines([
          // Center-top.
          #(6.0, 0.0),
          #(6.0, 11.0),
        ]),
        // Foot serif.
        p.lines([
          // Bottom-left.
          #(0.0, 11.0),
          #(12.0, 11.0),
        ]),
        // Beak.
        p.lines([
          #(1.0, 3.0),
          #(6.0, 3.0),
        ]),
      ])

    "2" ->
      p.lines([
        // Top-left.
        #(1.0, 3.0),
        #(1.0, 1.0),
        // Top-right.
        #(11.0, 1.0),
        #(11.0, 7.0),
        // Mid-left.
        #(1.0, 7.0),
        #(1.0, 11.0),
        #(12.0, 11.0),
      ])

    "3" ->
      p.combine([
        // Around.
        p.lines([
          // Top-left
          #(1.0, 3.0),
          #(1.0, 1.0),
          // Top-right.
          #(11.0, 1.0),
          #(11.0, 11.0),
          // Bottom-left.
          #(1.0, 11.0),
          #(1.0, 9.0),
        ]),
        // Middle stroke.
        p.lines([
          // Middle.
          #(5.0, 6.0),
          #(11.0, 6.0),
        ]),
      ])

    "4" ->
      p.combine([
        // Left angle.
        p.lines([
          // Mid-right.
          #(11.0, 7.0),
          #(1.0, 7.0),
          #(1.0, 0.0),
        ]),
        p.lines([
          // Top-right.
          #(11.0, 0.0),
          #(11.0, 12.0),
        ]),
      ])

    "5" ->
      view_letter("2", color)
      |> p.scale_y(-1.0)
      |> p.translate_y(12.0)

    "6" ->
      p.lines([
        // Mid-left.
        #(1.0, 5.0),
        #(11.0, 5.0),
        // Bottom-right.
        #(11.0, 11.0),
        #(1.0, 11.0),
        // Top-left.
        #(1.0, 1.0),
        #(12.0, 1.0),
      ])

    "7" ->
      p.lines([
        // Top-left.
        #(0.0, 1.0),
        #(11.0, 1.0),
        // Diagonal start.
        #(11.0, 3.0),
        #(7.0, 7.0),
        #(7.0, 12.0),
      ])

    "8" ->
      p.combine([
        // Top oval (top-half drawn only).
        p.lines([
          // Mid-left.
          #(2.0, 6.0),
          #(2.0, 1.0),
          // Top-right.
          #(10.0, 1.0),
          #(10.0, 6.0),
        ]),
        // Bottom oval.
        p.lines([
          // Mid-left.
          #(0.0, 6.0),
          #(11.0, 6.0),
          // Bottom-right.
          #(11.0, 11.0),
          #(1.0, 11.0),
          #(1.0, 6.0),
        ]),
      ])

    "9" ->
      view_letter("6", color)
      |> p.rotate(p.angle_rad(maths.pi()))
      |> p.translate_xy(12.0, 12.0)

    "←" ->
      p.combine([
        // Angle.
        p.lines([
          // Bottom-mid.
          #(6.0, 11.0),
          #(5.0, 11.0),
          #(1.0, 7.0),
          #(1.0, 5.0),
          #(5.0, 1.0),
          #(6.0, 1.0),
        ]),
        // Middle stroke.
        p.lines([
          #(1.0, 6.0),
          #(12.0, 6.0),
        ]),
      ])

    "→" ->
      view_letter("←", color)
      |> p.rotate(p.angle_rad(maths.pi()))
      |> p.translate_xy(12.0, 12.0)

    _ -> p.blank()
  }
  |> p.stroke(color, 2.0)
}

pub fn calc_text_width(text: String, scale: Float) -> Float {
  let length = int.to_float(string.length(text))

  {
    { { values.char_width +. values.char_spacing } *. length }
    -. values.char_spacing
  }
  *. scale
}
