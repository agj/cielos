[private]
@default:
    just --list --unsorted

# Builds files to `dist` folder.
build:
    gleam build

# Start development server.
develop:
    gleam run
