import gleam/float
import gleam/int
import gleam/io
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

  Model(
    avatar: Vector(pos: Vec2(0.0, 0.0), dir:),
    camera: Camera(lagging_dir: dir, start_move_time: 0.0),
    speed: 0.08,
    mouse_pos: Vec2(0.0, 0.0),
    current_time: 0.0,
  )
}

// CONSTANTS

const width = 300.0

const height = 300.0

const center = Vec2(150.0, 150.0)

const min_speed = 0.02

const max_speed = 0.4

const rotation_speed = 0.09

// MODEL

type Model {
  Model(
    avatar: Vector,
    camera: Camera,
    speed: Float,
    mouse_pos: Vec2(Float),
    current_time: Float,
  )
}

type Vector {
  Vector(pos: Vec2(Float), dir: Float)
}

type Object {
  Object(pos: Vec2(Float), height: Float)
}

type Camera {
  Camera(lagging_dir: Float, start_move_time: Float)
}

// UPDATE

fn update(model: Model, event: event.Event) -> Model {
  case event {
    event.Tick(updated_time) -> {
      Model(
        ..model,
        current_time: updated_time,
        avatar: move_avatar(
          model.avatar,
          speed: model.speed,
          delta_time: updated_time -. model.current_time,
        ),
      )
    }

    event.KeyboardPressed(event.KeyLeftArrow) -> change_rotation(model, -1.0)

    event.KeyboardPressed(event.KeyRightArrow) -> change_rotation(model, 1.0)

    event.KeyboardPressed(event.KeyUpArrow) -> change_speed(model, 1.0)

    event.KeyboardPressed(event.KeyDownArrow) -> change_speed(model, -1.0)

    event.MouseMoved(x, y) -> Model(..model, mouse_pos: Vec2(x, y))

    event.MousePressed(event.MouseButtonLeft) ->
      // Place avatar on click position.
      Model(
        ..model,
        avatar: Vector(
          ..model.avatar,
          pos: vec2f.subtract(model.mouse_pos, center),
        ),
      )

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

fn change_rotation(model: Model, direction: Float) -> Model {
  Model(
    ..model,
    avatar: rotate_avatar(model.avatar, direction),
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
  // let height_factor = 1.0
  // let camera_vector = Vector(pos: model.avatar.pos, dir: model.avatar.dir)

  // let content =
  //   p.combine(
  //     list.flatten([
  //       list.map(
  //         get_dots(around: model.avatar.pos, height: -3.0 *. height_factor),
  //         view_object(_, camera: camera_vector, picture: view_dot()),
  //       ),
  //       list.map(
  //         get_dots(around: model.avatar.pos, height: 3.0 *. height_factor),
  //         view_object(_, camera: camera_vector, picture: view_dot()),
  //       ),
  //       // [view_object(model.avatar, camera: camera_vector, picture: view_avatar())],
  //     ]),
  //   )
  //   // Center.
  //   |> p.translate_xy(center.x, center.y)

  let camera = Vector(pos: Vec2(0.0, 0.0), dir: model.avatar.dir)
  let picture = view_dot()
  let o = view_object(_, camera:, picture:)

  let content =
    p.combine(
      list.range(0, 20)
      |> list.map(fn(i) {
        let #(x, y) =
          maths.polar_to_cartesian(10.0, int.to_float(i) /. 20.0 *. maths.tau())

        view_object(
          Object(
            pos: Vec2(x, y),
            height: maths.sin(int.to_float(i) /. 20.0 *. maths.tau()),
          ),
          camera:,
          picture:,
        )
      }),
    )
    // Center.
    |> p.translate_xy(center.x, center.y)

  p.combine([view_background(), content])
}

fn view_background() -> p.Picture {
  p.rectangle(width, height)
  |> p.fill(colour.white)
  |> p.stroke_none
}

fn view_avatar(avatar: Vector, distance distance: Float) -> p.Picture {
  p.circle(15.0 *. get_scale(distance))
  |> p.fill(colour.purple)
  |> p.stroke_none
  |> p.translate_xy(avatar.pos.x, avatar.pos.y)
}

fn view_dot() -> p.Picture {
  p.circle(2.0)
  |> p.fill(colour.black)
  |> p.stroke_none
}

fn view_object(
  object: Object,
  camera camera: Vector,
  picture picture: p.Picture,
) -> p.Picture {
  let half_visible_angle = maths.degrees_to_radians(45.0)
  let angle_to_object =
    object.pos
    |> vec2f.subtract(camera.pos)
    |> fn(v) { normalize_angle(maths.atan2(v.y, v.x)) }
  let angle = normalize_angle(angle_to_object -. normalize_angle(camera.dir))

  case float.absolute_value(angle) >. half_visible_angle {
    True ->
      // Object is not within camera's visible area.
      p.blank()

    False -> {
      // Distance between camera and object (hypotenuse).
      let distance =
        float.absolute_value(vec2f.distance(camera.pos, object.pos))

      let scale = get_scale(distance)
      let translation =
        Vec2(
          angle *. center.x /. half_visible_angle,
          object.height *. 10.0 *. scale,
        )

      picture
      |> p.scale_uniform(scale)
      |> p.translate_xy(translation.x, translation.y)
    }
  }
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

// UTILS

fn get_camera_dir(
  camera: Camera,
  avatar_dir avatar_dir: Float,
  current_time current_time: Float,
) -> Float {
  let total_time = 200.0
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
  1.0 /. { { distance /. 100.0 } +. 1.0 }
}
