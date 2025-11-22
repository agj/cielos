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
    mouse_pos: Vec2(0.0, 0.0),
    last_time: 0.0,
  )
}

// CONSTANTS

const center = Vec2(150.0, 150.0)

const distance_between_dots = 20.0

const speed = 0.08

const rotation_speed = 0.09

// MODEL

type Model {
  Model(
    avatar: Vector,
    camera: Camera,
    mouse_pos: Vec2(Float),
    last_time: Float,
  )
}

type Vector {
  Vector(pos: Vec2(Float), dir: Float)
}

type Camera {
  Camera(lagging_dir: Float, start_move_time: Float)
}

// UPDATE

fn update(model: Model, event: event.Event) -> Model {
  case event {
    event.Tick(current_time) -> {
      Model(
        ..model,
        last_time: current_time,
        avatar: move_avatar(model.avatar, current_time -. model.last_time),
      )
    }

    event.KeyboardPressed(event.KeyLeftArrow) ->
      Model(
        ..model,
        avatar: rotate_avatar(model.avatar, -1.0),
        camera: Camera(
          lagging_dir: model.avatar.dir,
          start_move_time: model.last_time,
        ),
      )

    event.KeyboardPressed(event.KeyRightArrow) ->
      Model(..model, avatar: rotate_avatar(model.avatar, 1.0))

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

fn move_avatar(avatar: Vector, delta_time: Float) -> Vector {
  let r = speed *. delta_time
  let #(tx, ty) = maths.polar_to_cartesian(r, avatar.dir)

  Vector(..avatar, pos: vec2f.add(avatar.pos, Vec2(tx, ty)))
}

fn rotate_avatar(avatar: Vector, direction: Float) -> Vector {
  Vector(..avatar, dir: avatar.dir +. { rotation_speed *. direction })
}

// VIEW

fn view(model: Model) -> p.Picture {
  let camera_dir =
    get_camera_dir(model.camera, model.avatar.dir, model.last_time)

  p.combine(
    list.append(
      {
        get_dots_around(model.avatar.pos)
        |> list.map(view_dot)
      },
      [view_avatar(model.avatar)],
    ),
  )
  // Put origin on avatar.
  |> p.translate_xy(
    float.negate(model.avatar.pos.x),
    float.negate(model.avatar.pos.y),
  )
  // Rotate to follow avatar direction.
  |> p.rotate(
    p.angle_rad(float.negate(
      camera_dir
      // Correction to make it point upward.
      +. { maths.tau() *. 0.25 },
    )),
  )
  // Center.
  |> p.translate_xy(center.x, center.y)
}

fn get_camera_dir(
  camera: Camera,
  avatar_dir: Float,
  current_time: Float,
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

fn view_avatar(avatar: Vector) -> p.Picture {
  p.circle(10.0)
  |> p.fill(colour.purple)
  |> p.stroke_none
  |> p.translate_xy(avatar.pos.x, avatar.pos.y)
}

fn view_dot(pos: Vec2(Float)) {
  p.circle(1.0)
  |> p.fill(colour.black)
  |> p.stroke_none
  |> p.translate_xy(pos.x, pos.y)
}

fn get_dots_around(pos: Vec2(Float)) {
  let range = list.range(-10, 10)
  let x_base = float.floor(pos.x /. distance_between_dots)
  let y_base = float.floor(pos.y /. distance_between_dots)

  range
  |> list.flat_map(fn(x_offset) {
    let x_offset_float = int.to_float(x_offset)

    range
    |> list.map(fn(y_offset) {
      let y_offset_float = int.to_float(y_offset)

      Vec2(
        { x_offset_float *. distance_between_dots }
          +. { x_base *. distance_between_dots },
        { y_offset_float *. distance_between_dots }
          +. { y_base *. distance_between_dots },
      )
    })
  })
}
