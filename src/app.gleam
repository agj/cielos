import paint as p
import paint/canvas
import paint/event

pub fn main() {
  canvas.interact(init, update, view, "#app")
}

fn init(_config: canvas.Config) -> Model {
  todo
}

// MODEL

type Model

// UPDATE

fn update(model: Model, event: event.Event) -> Model {
  todo
}

// VIEW

fn view(model: Model) -> p.Picture {
  todo
}
