import gleam/float
import gleam/int
import gleam/list
import gleam_community/colour
import gleam_community/maths
import paint as p
import paint/canvas
import paint/event
import vec/vec2.{type Vec2, Vec2}
import vec/vec2f

pub fn main() {
  canvas.interact(init, update, view, "#app")
}

fn init(_config: canvas.Config) -> Model {
  let dir = 0.8 *. maths.tau()

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
  )
}

// CONSTANTS

const width = 300.0

const height = 300.0

const center = Vec2(150.0, 150.0)

const min_speed = 0.005

const max_speed = 0.4

const rotation_speed = 0.09

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

// UPDATE

fn update(model: Model, event: event.Event) -> Model {
  case event {
    event.Tick(updated_time) -> {
      let delta_time = updated_time -. model.current_time

      Model(
        ..model,
        current_time: updated_time,
        avatar: move_avatar(model.avatar, speed: model.speed, delta_time:),
      )
      |> change_rotation_by_dragging(delta_time)
    }

    event.KeyboardPressed(event.KeyLeftArrow) ->
      change_rotation_by_keyboard(model, -1.0)

    event.KeyboardPressed(event.KeyRightArrow) ->
      change_rotation_by_keyboard(model, 1.0)

    event.KeyboardPressed(event.KeyUpArrow) -> change_speed(model, 1.0)

    event.KeyboardPressed(event.KeyDownArrow) -> change_speed(model, -1.0)

    event.MouseMoved(x, y) -> Model(..model, mouse_pos: Vec2(x, y))

    event.MousePressed(event.MouseButtonLeft) ->
      Model(..model, drag: Dragging(start_pos: model.mouse_pos))

    event.MouseReleased(event.MouseButtonLeft) -> Model(..model, drag: NoDrag)

    // Ignore other events.
    _ -> model
  }
}

fn move_avatar(
  avatar: Vector,
  speed speed: Float,
  delta_time delta_time: Float,
) -> Vector {
  let r = speed *. delta_time
  let #(tx, ty) = maths.polar_to_cartesian(r, avatar.dir)

  Vector(..avatar, pos: vec2f.add(avatar.pos, Vec2(tx, ty)))
}

fn change_rotation_by_keyboard(model: Model, amount: Float) -> Model {
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

      change_rotation_by_keyboard(model, rotate_amount)
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

fn view(model: Model) -> p.Picture {
  let camera =
    Vector(
      ..model.avatar,
      dir: get_camera_dir(model.camera, model.avatar.dir, model.current_time),
    )

  let content =
    p.combine(
      model.objects
      |> list.map(view_object(_, camera:, current_time: model.current_time)),
    )
    // Center.
    |> p.translate_xy(center.x, center.y)

  p.combine([view_background(), content])
}

fn view_background() -> p.Picture {
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
) -> p.Picture {
  let steps_f = int.to_float(steps)
  let stripe_height = float.floor(height /. steps_f)

  list.range(0, steps)
  |> list.map(fn(i) {
    let i_f = int.to_float(i)
    let factor = {
      i_f /. steps_f
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

fn interpolate(from from: Float, to to: Float, by factor: Float) {
  { { to -. from } *. factor } +. from
}

fn view_star(current_time: Float) -> p.Picture {
  let assert Ok(star_color) = colour.from_hsl(0.12, 1.0, 0.7)
  let rotation = current_time /. 2000.0
  p.polygon(
    list.range(0, 10)
    |> list.map(fn(i) {
      let angle = { maths.tau() /. 10.0 *. int.to_float(i) } +. rotation
      let r = case i % 2 {
        0 -> 250.0
        _ -> 140.0
      }
      maths.polar_to_cartesian(r, angle)
    }),
  )
  |> p.fill(star_color)
  |> p.stroke_none
}

fn view_shadow() -> p.Picture {
  let assert Ok(shadow_color) = colour.from_hsla(0.75, 0.5, 0.4, 0.05)

  p.rectangle(200.0, 5000.0)
  |> p.fill(shadow_color)
  |> p.stroke_none
}

fn view_object(
  object: Object,
  camera camera: Vector,
  current_time current_time: Float,
) -> p.Picture {
  let half_visible_angle = maths.degrees_to_radians(45.0)
  let angle_x_to_object =
    angle_between(camera.pos.x, camera.pos.y, object.pos.x, object.pos.y)
  let angle_x = normalize_angle(angle_x_to_object -. camera.dir)

  case float.absolute_value(angle_x) >. half_visible_angle {
    True ->
      // Object is not within camera's visible area.
      p.blank()

    False -> {
      // Distance between camera and object.
      let distance_x =
        float.absolute_value(vec2f.distance(camera.pos, object.pos))
      let angle_y = angle_between(0.0, 0.0, distance_x, object.height)

      let scale = get_scale(distance_x)
      let translation =
        Vec2(
          angle_x *. center.x /. half_visible_angle,
          float.negate(angle_y *. center.x /. half_visible_angle),
        )

      get_picture_for_object(object.kind, current_time)
      |> p.scale_uniform(scale)
      |> p.translate_xy(translation.x, translation.y)
    }
  }
}

fn get_picture_for_object(
  object_kind: ObjectKind,
  current_time: Float,
) -> p.Picture {
  case object_kind {
    StarObject -> view_star(current_time)
    ShadowObject -> view_shadow()
  }
}

// UTILS

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

fn pos_from_polar(length length: Float, angle angle: Float) -> Vec2(Float) {
  let #(x, y) = maths.polar_to_cartesian(length, angle)
  Vec2(x, y)
}

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
