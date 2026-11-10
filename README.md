# hello_otp

`hello_otp` is a small Erlang/OTP application scaffold. Its application callback starts the top-level supervisor, `hello_otp_sup`, which currently has no child processes.

## Requirements

- Erlang/OTP
- [Rebar3](https://rebar3.org/)

## Build

From the project root, compile the application:

```powershell
rebar3 compile
```

## Run in the Erlang shell

Start the application in a Rebar3 shell:

```powershell
rebar3 shell
```

Then start the application from the Erlang prompt:

```erlang
application:ensure_all_started(hello_otp).
```

The application starts `hello_otp_sup`. Add worker or supervisor child specifications to `hello_otp_sup:init/1` as the application grows.
