port := "8080"

[private]
@default:
    just --list --unsorted

# Build release files on `dist` directory.
build: build-gleam
    pnpm install
    pnpm exec vite build --base './'

# Start development server.
develop: build-gleam qr
    #!/usr/bin/env nu
    http-server . --port {{port}} --silent -c-1 | lines | each { print $in }
    | interleave { watch ./src --glob='**/*.gleam' { try { just build-gleam } } }

# Build and deploy on Github Pages.
deploy: build
    pnpm exec gh-pages --dist ./dist

[private]
build-gleam:
    gleam build

[private]
qr:
    #!/usr/bin/env nu
    let ip = sys net | where name == "en0" | get ip.0 | where protocol == "ipv4" | get address.0
    let url = $"http://($ip):{{port}}"
    qrrs $url
    print $url
