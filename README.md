# hello_otp

`hello_otp` is an Erlang/OTP application with a persistent counter and a small HTTP page for trying it in a browser.

## Requirements

- Erlang/OTP
- [Rebar3](https://rebar3.org/)

## Run

Compile the application from the project root:

```powershell
rebar3 compile
```

Then start it in a Rebar3 shell:

```powershell
rebar3 shell
```

Open [http://localhost:8080](http://localhost:8080). The page displays the counter saved by the application. Select **Increment counter** to increase it; the value is stored in `data/hello_otp_counter.dets` and survives application restarts.

The HTTP listener binds to `127.0.0.1` on port `8080` by default. To choose another port, change `http_port` in `config/sys.config`:

```erlang
[{hello_otp, [{http_port, 8090}]}].
```

Then browse to `http://localhost:8090`.

## Endpoints

- `GET /` — display the current counter.
- `GET /increment` — increment the counter and display the new value.

The server uses Erlang's built-in TCP module and has no third-party dependencies.
