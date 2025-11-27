import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam_community/colour.{type Colour}
import gleam_community/maths
import paint.{type Picture} as p
import paint/canvas
import paint/event
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
    |> list.flat_map(fn(i) {
      let i_f = int.to_float(i)
      let pos =
        pos_from_polar(
          length: { i_f +. 1.0 } *. 2.0 +. 10.0,
          angle: i_f /. 20.0 *. maths.tau(),
        )
      let height = maths.sin(i_f /. 5.0 *. maths.tau())

      [
        Object(pos:, height:, kind: StarObject),
        Object(pos:, height: -10.0, kind: ShadowObject),
      ]
    })

  Model(
    avatar: Vector(pos: Vec2(0.0, 0.0), dir:),
    camera: Camera(lagging_dir: dir, start_move_time: 0.0),
    speed: 0.01,
    objects:,
    mouse_pos: Vec2(0.0, 0.0),
    drag: NoDrag,
    current_time: 0.0,
    paused: NotPaused,
    consts: Consts(
      background_picture: view_background(),
      shadow_picture: view_shadow(color_dark_blue_transparent),
      color_dark_blue:,
      color_dark_blue_transparent:,
      color_white_transparent:,
      color_yellow:,
      color_orange: colour.orange,
    ),
  )
}

// CONSTANTS

const width = 300.0

const height = 300.0

const center = Vec2(150.0, 150.0)

const min_speed = 0.005

const max_speed = 0.4

const rotation_speed = 0.09

// tau / 8
const half_visible_angle = 0.7853981634

// MODEL

type Model {
  Model(
    avatar: Vector,
    camera: Camera,
    speed: Float,
    objects: List(Object),
    mouse_pos: Vec2(Float),
    drag: Drag,
    current_time: Float,
    paused: PauseStatus,
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
  ShadowObject
}

type Camera {
  Camera(lagging_dir: Float, start_move_time: Float)
}

type Drag {
  NoDrag
  Dragging(start_pos: Vec2(Float))
}

type PauseStatus {
  Paused
  NotPaused
}

type Consts {
  Consts(
    background_picture: Picture,
    shadow_picture: Picture,
    color_dark_blue: Colour,
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
      Model(..model, current_time: updated_time)

    event.Tick(updated_time), NotPaused -> {
      let delta_time = updated_time -. model.current_time

      Model(..model, current_time: updated_time)
      |> move_avatar(delta_time:)
      |> change_rotation_by_dragging(delta_time)
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
    event.MouseMoved(x, y), _ -> Model(..model, mouse_pos: Vec2(x, y))

    event.MousePressed(event.MouseButtonLeft), NotPaused -> {
      let on_pause_button =
        model.mouse_pos.x <=. 30.0 && model.mouse_pos.y >=. { height -. 30.0 }

      case on_pause_button {
        True -> change_paused(model, Paused)
        False -> Model(..model, drag: Dragging(start_pos: model.mouse_pos))
      }
    }

    event.MousePressed(event.MouseButtonLeft), Paused ->
      change_paused(model, NotPaused)

    event.MouseReleased(event.MouseButtonLeft), NotPaused ->
      Model(..model, drag: NoDrag)

    // Ignore other events.
    _, _ -> model
  }
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

fn move_avatar(model: Model, delta_time delta_time: Float) -> Model {
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

fn change_rotation_by_dragging(model: Model, delta_time: Float) -> Model {
  case model.drag {
    NoDrag -> model
    Dragging(start_pos:) -> {
      let drag_factor =
        { model.mouse_pos.x -. start_pos.x } *. 0.001
        |> float.clamp(min: -0.02, max: 0.02)
      let rotate_amount = drag_factor *. delta_time

      change_rotation(model, rotate_amount)
    }
  }
}

fn change_speed(model: Model, direction: Float) -> Model {
  Model(
    ..model,
    speed: float.clamp(
      model.speed +. { direction *. { model.speed *. 0.05 } },
      min: min_speed,
      max: max_speed,
    ),
  )
}

fn rotate_avatar(avatar: Vector, direction: Float) -> Vector {
  Vector(..avatar, dir: avatar.dir +. { rotation_speed *. direction })
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
          <=. half_visible_angle

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
    |> p.translate_xy(center.x, center.y)

  p.combine([model.consts.background_picture, content, view_ui(model)])
}

fn view_ui(model: Model) -> Picture {
  view_pause_button(model.paused, model.consts)
  |> p.translate_xy(17.0, height -. 17.0)
}

fn view_pause_button(paused: PauseStatus, consts: Consts) -> Picture {
  p.combine([
    p.circle(15.0)
      |> p.fill(consts.color_white_transparent)
      |> p.stroke_none,
    case paused {
      Paused ->
        view_icon_play(consts.color_dark_blue)
        |> p.translate_xy(-6.0, -6.0)
      NotPaused ->
        view_icon_pause(consts.color_dark_blue)
        |> p.translate_xy(-6.0, -6.0)
    },
  ])
}

// VIEW OBJECT

fn view_object(
  object: Object,
  horizontal_angle_from_camera_center angle_x: Float,
  horizontal_distance_from_camera distance_x: Float,
  current_time current_time: Float,
  consts consts: Consts,
) -> Picture {
  let angle_y = angle_between(0.0, 0.0, distance_x, object.height)
  let is_far = distance_x >. 50.0
  let scale = case is_far {
    True -> 1.0
    False -> get_scale(distance_x)
  }
  let translation =
    Vec2(
      angle_x *. center.x /. half_visible_angle,
      float.negate(angle_y *. center.x /. half_visible_angle),
    )

  get_picture_for_object(object.kind, current_time, is_far, consts)
  |> p.scale_uniform(scale)
  |> p.translate_xy(translation.x, translation.y)
}

fn get_picture_for_object(
  object_kind: ObjectKind,
  current_time: Float,
  far: Bool,
  consts: Consts,
) -> Picture {
  case object_kind, far {
    StarObject, False -> view_star(current_time, consts)
    StarObject, True -> view_star_far(consts)
    ShadowObject, False -> consts.shadow_picture
    ShadowObject, True -> p.blank()
  }
}

fn view_star(current_time: Float, consts: Consts) -> Picture {
  let rotation = current_time /. 2000.0
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
  |> p.fill(consts.color_yellow)
  |> p.stroke(consts.color_orange, 10.0)
}

fn view_star_far(consts: Consts) -> Picture {
  p.circle(1.0)
  |> p.fill(consts.color_yellow)
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
      width:,
      height: height /. 2.0,
      steps: 50,
    ),
    view_gradient(
      from_h: 0.6,
      to_h: 0.6,
      from_s: 0.4,
      to_s: 0.7,
      from_l: 0.95,
      to_l: 0.8,
      width:,
      height: height /. 2.0,
      steps: 50,
    )
      |> p.translate_y(center.y),
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
  let total_time = 100.0
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
