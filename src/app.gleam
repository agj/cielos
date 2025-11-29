import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import gleam_community/colour.{type Colour}
import gleam_community/maths
import js
import paint.{type Picture} as p
import paint/canvas
import paint/event
import text
import values
import vec/vec2.{type Vec2, Vec2}
import vec/vec2f

pub fn main() {
  canvas.interact(init, update, view, "#app")
}

fn init(_config: canvas.Config) -> Model {
  let dir = 0.8 *. maths.tau()
  let assert Ok(color_white_transparent) = colour.from_hsla(0.0, 1.0, 1.0, 0.5)
  let assert Ok(color_dark_blue) = colour.from_hsl(0.6, 0.7, 0.7)
  let assert Ok(color_dark_blue_transparent) =
    colour.from_hsla(0.75, 0.5, 0.4, 0.05)
  let assert Ok(color_yellow) = colour.from_hsl(0.12, 1.0, 0.7)

  let objects =
    list.range(0, 200)
    |> list.map(fn(i) {
      let i_f = int.to_float(i)
      let pos =
        pos_from_polar(
          length: { i_f +. 1.0 } *. 2.0 +. 10.0,
          angle: i_f /. 20.0 *. maths.tau(),
        )
      let height = maths.sin(i_f /. 5.0 *. maths.tau())

      Object(pos:, height:, kind: StarObject)
    })

  Model(
    avatar: Vector(pos: Vec2(0.0, 0.0), dir:),
    camera: Camera(lagging_dir: dir, start_move_time: 0.0),
    speed: 0.01,
    objects:,
    mouse: Mouse(pos: Vec2(0.0, 0.0), prev_pos: Vec2(0.0, 0.0)),
    drag: NoDrag,
    current_time: 0.0,
    prev_tick_time: 0.0,
    paused: Paused,
    press_regions: list.flatten([
      [pause_press_region()],
      links_press_regions(),
    ]),
    consts: Consts(
      background_picture: view_background(),
      shadow_picture: view_shadow(color_dark_blue_transparent),
      color_dark_blue:,
      color_dark_blue_transparent:,
      color_white: colour.white,
      color_white_transparent:,
      color_yellow:,
      color_orange: colour.orange,
    ),
  )
}

// MODEL

type Model {
  Model(
    avatar: Vector,
    camera: Camera,
    speed: Float,
    objects: List(Object),
    mouse: Mouse,
    drag: Drag,
    current_time: Float,
    prev_tick_time: Float,
    paused: PauseStatus,
    press_regions: List(PressRegion),
    consts: Consts,
  )
}

type Vector {
  Vector(pos: Vec2(Float), dir: Float)
}

type Object {
  Object(pos: Vec2(Float), height: Float, kind: ObjectKind)
}

type ObjectKind {
  StarObject
  CollectedStarObject(collected_time: Float)
}

type Camera {
  Camera(lagging_dir: Float, start_move_time: Float)
}

type Mouse {
  Mouse(pos: Vec2(Float), prev_pos: Vec2(Float))
}

type Drag {
  NoDrag
  Dragging(start_pos: Vec2(Float), start_avatar_dir: Float)
  Flicked(force: Float, released_time: Float)
}

type PauseStatus {
  Paused
  NotPaused
}

type PressRegion {
  PressRegion(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    on_press: fn(Model) -> Model,
  )
}

type Consts {
  Consts(
    background_picture: Picture,
    shadow_picture: Picture,
    color_dark_blue: Colour,
    color_white: Colour,
    color_white_transparent: Colour,
    color_yellow: Colour,
    color_orange: Colour,
    color_dark_blue_transparent: Colour,
  )
}

// UPDATE

fn update(model: Model, event: event.Event) -> Model {
  case event, model.paused {
    event.Tick(updated_time), Paused ->
      Model(..model, current_time: updated_time, drag: NoDrag)

    event.Tick(updated_time), NotPaused -> {
      Model(
        ..model,
        current_time: updated_time,
        prev_tick_time: model.current_time,
      )
      |> move_avatar
      |> change_rotation_by_drag_or_flick
      |> check_collisions
    }

    // Keyboard.
    event.KeyboardPressed(event.KeyLeftArrow), NotPaused ->
      change_rotation(model, -1.0)

    event.KeyboardPressed(event.KeyRightArrow), NotPaused ->
      change_rotation(model, 1.0)

    event.KeyboardPressed(event.KeyUpArrow), NotPaused ->
      change_speed(model, 1.0)

    event.KeyboardPressed(event.KeyDownArrow), NotPaused ->
      change_speed(model, -1.0)

    event.KeyboardPressed(event.KeyEscape), _ ->
      change_paused(model, flip_paused(model.paused))

    // Mouse.
    event.MousePressed(event.MouseButtonLeft), _ -> {
      let press_region =
        model.press_regions
        |> list.find(fn(region) {
          model.mouse.pos.x >=. region.x
          && model.mouse.pos.x <. region.x +. region.width
          && model.mouse.pos.y >=. region.y
          && model.mouse.pos.y <. region.y +. region.height
        })

      case press_region {
        Ok(region) -> region.on_press(model)

        Error(_) -> {
          // If there are no regions, we just do the default action.
          case model.paused {
            Paused -> change_paused(model, NotPaused)
            NotPaused ->
              Model(
                ..model,
                drag: Dragging(
                  start_pos: model.mouse.pos,
                  start_avatar_dir: model.avatar.dir,
                ),
                // Adjustment made for touch interfaces, which don't receive
                // `MouseMoved` events before touch.
                mouse: Mouse(..model.mouse, prev_pos: model.mouse.pos),
              )
          }
        }
      }
    }

    event.MouseMoved(x, y), _ ->
      Model(..model, mouse: Mouse(pos: Vec2(x, y), prev_pos: model.mouse.pos))

    event.MouseReleased(event.MouseButtonLeft), NotPaused -> set_flicking(model)

    // Ignore other events.
    _, _ -> model
  }
}

fn check_collisions(model: Model) -> Model {
  let non_collided_objects =
    model.objects
    |> list.map(fn(object) {
      case
        { object.kind == StarObject }
        && { vec2f.distance(model.avatar.pos, object.pos) <. 0.8 }
      {
        True ->
          Object(
            ..object,
            kind: CollectedStarObject(collected_time: model.current_time),
          )
        False -> object
      }
    })

  Model(..model, objects: non_collided_objects)
}

fn change_paused(model: Model, new_paused: PauseStatus) -> Model {
  Model(..model, paused: new_paused, drag: NoDrag)
}

fn flip_paused(paused: PauseStatus) -> PauseStatus {
  case paused {
    Paused -> NotPaused
    NotPaused -> Paused
  }
}

fn move_avatar(model: Model) -> Model {
  let delta_time = model.current_time -. model.prev_tick_time
  let r = model.speed *. delta_time
  let #(tx, ty) = maths.polar_to_cartesian(r, model.avatar.dir)

  Model(
    ..model,
    avatar: Vector(
      ..model.avatar,
      pos: vec2f.add(model.avatar.pos, Vec2(tx, ty)),
    ),
  )
}

fn change_rotation(model: Model, amount: Float) -> Model {
  Model(
    ..model,
    avatar: rotate_avatar(model.avatar, amount),
    camera: Camera(
      start_move_time: model.current_time,
      lagging_dir: get_camera_dir(
        model.camera,
        avatar_dir: model.avatar.dir,
        current_time: model.current_time,
      ),
    ),
  )
}

fn change_rotation_by_drag_or_flick(model: Model) -> Model {
  case model.drag {
    NoDrag -> model

    Dragging(start_pos:, start_avatar_dir:) -> {
      let drag_diff = model.mouse.pos.x -. start_pos.x
      let angle_diff = drag_diff *. 0.005

      Model(
        ..model,
        avatar: Vector(..model.avatar, dir: start_avatar_dir -. angle_diff),
      )
    }

    Flicked(force:, released_time:) -> {
      let delta_time = model.current_time -. model.prev_tick_time
      let time_since_flick = model.current_time -. released_time
      let angle_diff =
        { 100.0 /. time_since_flick } *. force *. delta_time *. 0.005

      Model(
        ..model,
        avatar: Vector(..model.avatar, dir: model.avatar.dir -. angle_diff),
      )
    }
  }
}

fn set_flicking(model: Model) -> Model {
  case model.drag {
    NoDrag -> model
    Flicked(..) -> model
    Dragging(..) -> {
      let flick_diff = model.mouse.pos.x -. model.mouse.prev_pos.x
      let flick_time = model.current_time -. model.prev_tick_time
      let force = flick_diff /. flick_time

      case float.absolute_value(force) >. 0.01 {
        True ->
          Model(
            ..model,
            drag: Flicked(force:, released_time: model.current_time),
          )
        False -> Model(..model, drag: NoDrag)
      }
    }
  }
}

fn change_speed(model: Model, direction: Float) -> Model {
  Model(
    ..model,
    speed: float.clamp(
      model.speed +. { direction *. { model.speed *. 0.05 } },
      min: values.min_speed,
      max: values.max_speed,
    ),
  )
}

fn rotate_avatar(avatar: Vector, direction: Float) -> Vector {
  Vector(..avatar, dir: avatar.dir +. { values.rotation_speed *. direction })
}

// VIEW

fn view(model: Model) -> Picture {
  let camera =
    Vector(
      ..model.avatar,
      dir: get_camera_dir(model.camera, model.avatar.dir, model.current_time),
    )

  let content =
    p.combine(
      model.objects
      |> list.filter_map(fn(object) {
        let horizontal_angle_from_camera_pos =
          angle_between(camera.pos.x, camera.pos.y, object.pos.x, object.pos.y)
        let horizontal_angle_from_camera_center =
          normalize_angle(horizontal_angle_from_camera_pos -. camera.dir)
        let horizontal_distance_from_camera =
          float.absolute_value(vec2f.distance(camera.pos, object.pos))
        let in_field_of_view =
          float.absolute_value(horizontal_angle_from_camera_center)
          <=. values.half_visible_angle

        case in_field_of_view {
          True ->
            Ok(#(
              object,
              horizontal_angle_from_camera_center,
              horizontal_distance_from_camera,
            ))
          False -> Error(Nil)
        }
      })
      |> list.sort(fn(a, b) { order.negate(float.compare(a.2, b.2)) })
      |> list.map(fn(args) {
        view_object(
          args.0,
          horizontal_angle_from_camera_center: args.1,
          horizontal_distance_from_camera: args.2,
          current_time: model.current_time,
          consts: model.consts,
        )
      }),
    )
    // Center.
    |> p.translate_xy(values.center.x, values.center.y)

  p.combine([model.consts.background_picture, content, view_ui(model)])
}

fn view_ui(model: Model) -> Picture {
  p.combine([
    case model.paused {
      Paused ->
        p.combine([
          view_title(model.current_time, model.consts)
            |> p.translate_xy(0.0, 80.0),
          view_instructions(model.current_time, model.consts)
            |> p.translate_xy(0.0, 200.0),
          view_links(model.current_time, model.consts),
        ])
      NotPaused -> p.blank()
    },
    view_pause_button(model.paused, model.current_time, model.consts)
      |> p.translate_xy(17.0, values.height -. 17.0),
  ])
}

/// Rendered already centered horizontally on the screen, though vertically it's
/// at 0.
fn view_title(current_time: Float, consts: Consts) -> Picture {
  let top_text = "cielos"
  let top_text_scale = 1.5
  let top_text_width = text.calc_text_width(top_text, top_text_scale)
  let bottom_text = "by agj"
  let bottom_text_scale = 0.75
  let bottom_text_width = text.calc_text_width(bottom_text, bottom_text_scale)

  p.combine([
    text.view_wobbly_text(
      top_text,
      current_time:,
      color: consts.color_dark_blue,
    )
      |> p.scale_uniform(top_text_scale),
    text.view_wobbly_text(
      bottom_text,
      current_time:,
      color: consts.color_dark_blue,
    )
      |> p.scale_uniform(bottom_text_scale)
      |> p.translate_xy({ top_text_width } -. { bottom_text_width }, 40.0),
  ])
  |> p.translate_x({ values.width *. 0.5 } -. { top_text_width *. 0.5 })
}

/// Rendered already centered horizontally on the screen, though vertically it's
/// at 0.
fn view_instructions(current_time: Float, consts: Consts) -> Picture {
  let texts = ["flick ←→ to turn", "collect stars"]
  let scale = 0.75
  let max_width =
    texts
    |> list.sort(fn(a, b) {
      order.negate(int.compare(string.length(a), string.length(b)))
    })
    |> list.first
    |> result.map(text.calc_text_width(_, scale))
    |> result.unwrap(0.0)

  p.combine(
    texts
    |> list.index_map(fn(text, i) {
      text.view_wobbly_text(text, current_time:, color: consts.color_dark_blue)
      |> p.translate_y(values.char_width *. 2.5 *. int.to_float(i))
    }),
  )
  |> p.scale_uniform(scale)
  |> p.translate_x({ values.width *. 0.5 } -. { max_width *. 0.5 })
}

fn view_pause_button(
  paused: PauseStatus,
  current_time: Float,
  consts: Consts,
) -> Picture {
  p.combine([
    p.circle(15.0)
      |> p.fill(consts.color_white_transparent)
      |> p.stroke_none,
    case paused {
      Paused -> {
        let label_text = "esc"
        let label_scale = 0.5
        let label =
          text.view_wobbly_text(
            label_text,
            current_time,
            consts.color_white_transparent,
          )
          |> p.scale_uniform(label_scale)

        p.combine([
          view_icon_play(consts.color_dark_blue)
            |> p.translate_xy(-6.0, -6.0),
          label
            |> p.translate_xy(
              text.calc_text_width(label_text, label_scale) *. -0.5,
              -27.0,
            ),
        ])
      }
      NotPaused ->
        view_icon_pause(consts.color_dark_blue)
        |> p.translate_xy(-6.0, -6.0)
    },
  ])
}

fn pause_press_region() -> PressRegion {
  PressRegion(
    x: 0.0,
    y: values.height -. 30.0,
    width: 30.0,
    height: 30.0,
    on_press: fn(model) { change_paused(model, flip_paused(model.paused)) },
  )
}

const button_width = 60.0

const button_height = 20.0

fn view_links(current_time: Float, consts: Consts) -> Picture {
  view_button("about", current_time, consts)
  |> p.translate_xy(
    values.width -. button_width -. 2.0,
    values.height -. button_height -. 2.0,
  )
}

fn links_press_regions() -> List(PressRegion) {
  [
    PressRegion(
      x: values.width -. button_width -. 2.0,
      y: values.height -. button_height -. 2.0,
      width: button_width,
      height: button_height,
      on_press: fn(model) {
        js.open_url_in_new_tab("https://github.com/agj/cielos")
        model
      },
    ),
  ]
}

fn view_button(label: String, current_time, consts: Consts) -> Picture {
  let text_scale = 0.5
  let text_width = text.calc_text_width(label, text_scale)

  p.combine([
    p.rectangle(button_width, 20.0),
    text.view_wobbly_text(label, current_time, consts.color_dark_blue)
      |> p.scale_uniform(text_scale)
      |> p.translate_xy(
        { button_width *. 0.5 } -. { text_width *. 0.5 },
        { button_height *. 0.5 } -. { values.char_width *. text_scale *. 0.5 },
      ),
  ])
  |> p.fill(consts.color_white_transparent)
  |> p.stroke_none
}

// VIEW OBJECT

fn view_object(
  object: Object,
  horizontal_angle_from_camera_center angle_hor: Float,
  horizontal_distance_from_camera distance_hor: Float,
  current_time current_time: Float,
  consts consts: Consts,
) -> Picture {
  let angle_ver = angle_between(0.0, 0.0, distance_hor, object.height)
  let is_far = distance_hor >. 50.0
  let scale = case is_far {
    True -> 1.0
    False -> get_scale(distance_hor)
  }
  let translation =
    Vec2(
      angle_hor *. values.center.x /. values.half_visible_angle,
      float.negate(angle_ver *. values.center.x /. values.half_visible_angle),
    )

  let object_picture =
    get_picture_for_object(object.kind, current_time, is_far, consts)
    |> p.scale_uniform(scale)
    |> p.translate_xy(translation.x, translation.y)

  let shadow_picture = case is_far {
    True -> p.blank()

    False -> {
      let shadow_height = -10.0
      let shadow_angle_ver =
        angle_between(0.0, 0.0, distance_hor, shadow_height)
      let shadow_translation =
        Vec2(
          translation.x,
          float.negate(
            shadow_angle_ver *. values.center.x /. values.half_visible_angle,
          ),
        )

      consts.shadow_picture
      |> p.scale_uniform(scale)
      |> p.translate_xy(shadow_translation.x, shadow_translation.y)
    }
  }

  p.combine([shadow_picture, object_picture])
}

fn get_picture_for_object(
  object_kind: ObjectKind,
  current_time: Float,
  far: Bool,
  consts: Consts,
) -> Picture {
  case far, object_kind {
    False, StarObject -> view_star(current_time, consts, collected_time: None)
    False, CollectedStarObject(collected_time:) ->
      view_star(current_time, consts, collected_time: Some(collected_time))

    True, StarObject -> view_star_far(consts, collected: False)
    True, CollectedStarObject(_) -> view_star_far(consts, collected: True)
  }
}

fn view_star(
  current_time: Float,
  consts: Consts,
  collected_time collected_time: Option(Float),
) -> Picture {
  let rotation = current_time /. 2000.0

  case collected_time {
    None ->
      // Non-collected star.
      view_star_picture(
        fill_color: consts.color_yellow,
        stroke_color: consts.color_orange,
        rotation:,
      )

    Some(time) if current_time -. time <=. 1000.0 ->
      // Explosion when collecting.
      p.circle(1000.0)
      |> p.fill(consts.color_white)
      |> p.stroke_none

    Some(_) ->
      // Collected star.
      view_star_picture(
        fill_color: consts.color_white,
        stroke_color: consts.color_yellow,
        rotation:,
      )
  }
}

fn view_star_picture(
  fill_color fill_color: Colour,
  stroke_color stroke_color: Colour,
  rotation rotation: Float,
) -> Picture {
  p.polygon(
    list.range(0, 10)
    |> list.map(fn(i) {
      let angle = { maths.tau() /. 10.0 *. int.to_float(i) } +. rotation
      // Spike or valley in star geometry.
      let r = case i % 2 {
        0 -> 250.0
        _ -> 140.0
      }
      maths.polar_to_cartesian(r, angle)
    }),
  )
  |> p.fill(fill_color)
  |> p.stroke(stroke_color, 10.0)
}

fn view_star_far(consts: Consts, collected collected: Bool) -> Picture {
  let color = case collected {
    True -> consts.color_white
    False -> consts.color_yellow
  }

  p.circle(1.0)
  |> p.fill(color)
  |> p.stroke_none
}

fn view_shadow(color: Colour) -> Picture {
  p.rectangle(200.0, 5000.0)
  |> p.translate_x(-100.0)
  |> p.fill(color)
  |> p.stroke_none
}

// VIEW BACKGROUND

fn view_background() -> Picture {
  [
    view_gradient(
      from_h: 0.85,
      to_h: 0.7,
      from_s: 0.6,
      to_s: 0.4,
      from_l: 0.9,
      to_l: 0.98,
      width: values.width,
      height: values.height /. 2.0,
      steps: 50,
    ),
    view_gradient(
      from_h: 0.6,
      to_h: 0.6,
      from_s: 0.4,
      to_s: 0.7,
      from_l: 0.95,
      to_l: 0.8,
      width: values.width,
      height: values.height /. 2.0,
      steps: 50,
    )
      |> p.translate_y(values.center.y),
  ]
  |> p.combine
}

fn view_gradient(
  from_h from_h: Float,
  from_s from_s: Float,
  from_l from_l: Float,
  to_h to_h: Float,
  to_s to_s: Float,
  to_l to_l: Float,
  width width: Float,
  height height: Float,
  steps steps: Int,
) -> Picture {
  let steps_f = int.to_float(steps)
  let stripe_height = float.floor(height /. steps_f)

  list.range(0, steps)
  |> list.map(fn(i) {
    let i_f = int.to_float(i)
    let factor = {
      i_f /. { steps_f -. 1.0 }
    }
    let assert Ok(bg_color) =
      colour.from_hsl(
        interpolate(from: from_h, to: to_h, by: factor),
        interpolate(from: from_s, to: to_s, by: factor),
        interpolate(from: from_l, to: to_l, by: factor),
      )

    p.rectangle(width, stripe_height)
    |> p.translate_y(stripe_height *. i_f)
    |> p.fill(bg_color)
    |> p.stroke_none
  })
  |> p.combine
}

// ICONS

/// Pause icon, with dimensions 12×12 and origin on top left.
fn view_icon_pause(color: Colour) -> Picture {
  let bar = p.rectangle(4.0, 12.0)

  p.combine([
    bar,
    bar |> p.translate_xy(8.0, 0.0),
  ])
  |> p.fill(color)
  |> p.stroke_none
}

/// Play icon, with dimensions 12×12 and origin on top left.
fn view_icon_play(color: Colour) -> Picture {
  p.polygon([
    #(2.0, 0.0),
    #(11.0, 6.0),
    #(2.0, 12.0),
  ])
  |> p.fill(color)
  |> p.stroke_none
}

// UTILS

/// Gets the direction (as an angle in radians) that the camera is facing at the
/// current time, smoothing out rotation after user input, and with the avatar's
/// direction as its base.
fn get_camera_dir(
  camera: Camera,
  avatar_dir avatar_dir: Float,
  current_time current_time: Float,
) -> Float {
  let total_time = 50.0
  let start_time = camera.start_move_time
  let end_time = start_time +. total_time

  case current_time >=. end_time {
    True -> avatar_dir

    False -> {
      let rotation_progress = { current_time -. start_time } /. total_time

      { avatar_dir *. rotation_progress }
      +. { camera.lagging_dir *. { 1.0 -. rotation_progress } }
    }
  }
}

/// Gets a scale factor for an object that is `distance` units away from the
/// camera.
fn get_scale(distance: Float) -> Float {
  // Maximum possible scale.
  let peak = 1.0
  // How softly the scale decreases as the distance increases.
  let gentleness = 0.2
  peak /. { { distance /. gentleness } +. 1.0 }
}

/// Transforms polar coordinates to cartesian, and returns as a `Vec2` value.
fn pos_from_polar(length length: Float, angle angle: Float) -> Vec2(Float) {
  let #(x, y) = maths.polar_to_cartesian(length, angle)
  Vec2(x, y)
}

/// Calculates the angle (in radians) between two 2D coordinates.
fn angle_between(
  from_x from_x: Float,
  from_y from_y: Float,
  to_x to_x: Float,
  to_y to_y: Float,
) -> Float {
  maths.atan2(to_y -. from_y, to_x -. from_x)
}

/// Normalizes an angle in radians between pi (inclusive) and -pi (exclusive).
/// This makes it easier to compare and interpolate between angles.
fn normalize_angle(radians: Float) -> Float {
  let tau = maths.tau()
  let pi = maths.pi()
  let minus_pi = float.negate(pi)
  case radians {
    r if r >. pi -> normalize_angle(r -. tau)
    r if r <=. minus_pi -> normalize_angle(r +. tau)
    r -> r
  }
}

/// Interpolates between two `Float` values `by` a factor from `0.0` through
/// `1.0`.
fn interpolate(from from: Float, to to: Float, by factor: Float) {
  { { to -. from } *. factor } +. from
}
