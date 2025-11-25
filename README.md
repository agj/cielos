# Cielos

A simple game made by agj for the 2025 [Gleam Game
Jam](https://gamejam.gleam.community/), under the theme “Lucy in the sky with
diamonds”.

[**Play here ☁️**](https://agj.github.io/cielos/)

This game was written in the [Gleam](https://gleam.run/) programming language,
using the [paint](https://hexdocs.pm/paint/paint/event.html) graphics library.

## Development

You'll need Nix installed. If you also have direnv installed, do `direnv allow`
after navigating into this directory in your terminal. Otherwise, do `nix
develop` (requires flakes enabled) to enter a shell with dependencies loaded in.

Enter `just` to see the tasks available.

- `just develop` will launch a development server.
- `just build` will create the release files under the `dist` directory.
