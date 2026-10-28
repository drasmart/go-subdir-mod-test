# go-subdir-mod-test

Shows that a Go module can live in a **subdirectory** of a multi-module repository and be fetched with plain `go get`, with no separate repository per module.

## What it loads

| | |
| --- | --- |
| Repository | <https://github.com/aws/aws-sdk-go-v2> |
| Module directory | `service/s3/` |
| Module path (from that directory's `go.mod`) | `github.com/aws/aws-sdk-go-v2/service/s3` |
| Version requested | `v1.114.6` |
| Git tag it resolves to | `service/s3/v1.114.6` (directory prefix + version) |
| Commit the tag points to | `c350990c95a551ec1bb7b30a76d25bce33ecd389` |
| Module hash (`go.sum`) | `h1:to7+Vr3rLkpYRwVKJ5QRriI0eE306vrVN/6TnVHgxvY=` |

Links:

- Tag: <https://github.com/aws/aws-sdk-go-v2/releases/tag/service%2Fs3%2Fv1.114.6>
- Directory at the tag: <https://github.com/aws/aws-sdk-go-v2/tree/service/s3/v1.114.6/service/s3>
- `go.mod` at the tag: <https://github.com/aws/aws-sdk-go-v2/blob/service/s3/v1.114.6/service/s3/go.mod>
- Same directory by commit: <https://github.com/aws/aws-sdk-go-v2/tree/c350990c95a551ec1bb7b30a76d25bce33ecd389/service/s3>

`v1.114.6` on its own is **not** a tag in this repository; only the prefixed `service/s3/v1.114.6` exists. These return 404:

- <https://github.com/aws/aws-sdk-go-v2/releases/tag/v1.114.6>
- <https://github.com/aws/aws-sdk-go-v2/tree/v1.114.6>

So the version in `go.mod` (`v1.114.6`) is not looked up as a tag of that name: Go puts the module's directory in front of it.

## How Go resolves it

For `go get github.com/aws/aws-sdk-go-v2/service/s3@v1.114.6`:

1. `github.com/aws/aws-sdk-go-v2` is the repository; the rest of the path, `service/s3`, is the directory inside it.
2. The version is looked up as the tag `<directory>/<version>`: `service/s3/v1.114.6`.
3. The module zip contains only `service/s3/` at that tag, and its `go.mod` must declare exactly the requested module path.

The same scheme works with a major-version suffix. For a 51Degrees monorepo it would be:

- `device-detection-go/go.mod`: `module github.com/51Degrees/51degrees-go/device-detection-go/v4`
- tag: `device-detection-go/v4.5.30`

The suffix `/v4` is part of the module path, not the directory, and the tag prefix is the directory only. A live example is `github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/compute/armcompute/v5`, tag `sdk/resourcemanager/compute/armcompute/v5.7.0`.

## Quick proof

```powershell
./LAUNCHME.ps1
```

[LAUNCHME.ps1](LAUNCHME.ps1) uses a new, empty module cache with the proxy bypassed. It shows the repository, subdirectory, tag and commit Go resolved the module from, then runs the test and the demo, and prints a summary. Afterwards it restores the Go environment variables and deletes the temporary cache (`-KeepCache` keeps it). Your own module cache is not touched.

## Layout

- [s3lib/s3lib.go](s3lib/s3lib.go): `ListBucketNames(ctx, endpoint)` wraps the S3 `ListBuckets` API call from the s3 module.
- [s3lib/s3lib_test.go](s3lib/s3lib_test.go): runs `ListBucketNames` against a local fake S3 endpoint (`httptest`) and checks it returns the two bucket names, with no error. No network access to AWS and no credentials needed.
- [main.go](main.go): prints which s3 module version the build resolved.

## Test

```sh
go test -v ./...
```

Expected:

```text
--- PASS: TestListBucketNames
ok      example.com/go-subdir-mod-test/s3lib
```

To prove the module comes from the GitHub subdirectory and tag (not from the proxy or a local cache), run the test with the proxy bypassed and an empty module cache. `<empty dir>` is any new directory; delete it afterwards.

```sh
GOMODCACHE=<empty dir> GOPROXY=direct GOFLAGS=-modcacherw go test -count=1 ./...
```

PowerShell (fresh terminal; the variables stay set for the session):

```powershell
$env:GOMODCACHE="$env:TEMP\gomod-test"; $env:GOPROXY="direct"; $env:GOFLAGS="-modcacherw"; go test -count=1 ./...
```

## Run

```sh
go run .
```

Expected output:

```text
s3.ServiceID: S3
resolved module: github.com/aws/aws-sdk-go-v2/service/s3 v1.114.6 (h1:to7+Vr3rLkpYRwVKJ5QRriI0eE306vrVN/6TnVHgxvY=)
```

By default this goes through `proxy.golang.org`. To show that resolution works from GitHub itself, bypass the proxy and use an empty cache (`<empty dir>` is any new directory; delete it afterwards):

```sh
GOMODCACHE=<empty dir> GOPROXY=direct GOFLAGS=-modcacherw go run .
```

It prints the same version and the same `h1:` hash. That run checked out the tag `service/s3/v1.114.6` from GitHub, extracted `service/s3/` and verified the hash against `sum.golang.org`.
