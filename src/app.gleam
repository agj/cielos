import gleam/float
import gleam/int
import gleam_community/colour
import paint as p
import paint/canvas
import paint/event
import vec/vec2.{type Vec2, Vec2}
import vec/vec2f

pub fn main() {
  canvas.interact(init, update, view, "#app")
}

fn init(_config: canvas.Config) -> Model {
  Model(avatar: Vector(pos: Vec2(0.0, 0.0), dir: 0.0))
}

// MODEL

type Model {
  Model(avatar: Vector)
}

type Vector {
  Vector(pos: Vec2(Float), dir: Float)
}

// UPDATE

fn update(model: Model, event: event.Event) -> Model {
  case event {
    event.Tick(t) -> Model(..model, avatar: move_avatar(model.avatar))

    _ -> model
  }
}

fn move_avatar(avatar: Vector) -> Vector {
  Vector(pos: vec2f.zero, dir: 0.0)
}

// VIEW

const center = Vec2(150.0, 150.0)

fn view(model: Model) -> p.Picture {
  view_avatar(model.avatar)
  |> p.translate_xy(center.x, center.y)
}

fn view_avatar(avatar: Vector) -> p.Picture {
  p.circle(10.0)
  |> p.fill(colour.purple)
  |> p.stroke_none
  |> p.translate_xy(avatar.pos.x, avatar.pos.y)
}
