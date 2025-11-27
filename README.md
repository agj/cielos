# Cielos

A simple interactive experience inspired mechanically and aesthetically by Sega
“blue sky” games like Space Harrier and Nights into Dreams.

[**Play here ⭐️☁️**](https://agj.github.io/cielos/)

Made by agj for the 2025 [Gleam Game Jam](https://gamejam.gleam.community/),
under the theme “Lucy in the sky with diamonds”. Written in
the [Gleam](https://gleam.run/) programming language, using the
[paint](https://hexdocs.pm/paint/paint/event.html) graphics library.

The typeface used within the game is an ad-hoc collection of glyphs drawn using
a 12×12 grid.

## Development

You'll need Nix installed. If you also have direnv installed, do `direnv allow`
after navigating into this directory in your terminal. Otherwise, do `nix
develop` (requires flakes enabled) to enter a shell with dependencies loaded in.

Enter `just` to see the tasks available.

- `just develop` will launch a development server.
- `just build` will create the release files under the `dist` directory.
