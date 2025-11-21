[private]
@default:
    just --list --unsorted

# Builds files to `dist` folder.
build:
    gleam build

# Start development server.
develop: build
    #!/usr/bin/env nu
    http-server . | lines | each { print $in }
    | interleave { watch ./src --glob='**/*.gleam' { just build } }
