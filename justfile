[private]
@default:
    just --list --unsorted

# Builds files to `dist` folder.
build:
    gleam build

# Start development server.
develop: build
    #!/usr/bin/env nu
    simple-http-server . --index --silent
    | lines
    | interleave { watch ./src --glob='**/*.gleam' { just build } }
