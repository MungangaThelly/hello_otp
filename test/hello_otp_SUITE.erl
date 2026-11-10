
%%%-------------------------------------------------------------------
%% @doc Common Test integration suite for hello_otp.
%%%-------------------------------------------------------------------

-module(hello_otp_SUITE).

-include_lib("common_test/include/ct.hrl").

-export([
    all/0,
    init_per_suite/1,
    end_per_suite/1,
    application_starts/1,
    counter_operations/1,
    storage_consistency/1,
    worker_recovery/1
]).

%% Test execution order
all() ->
    [
        application_starts,
        counter_operations,
        storage_consistency,
        worker_recovery
    ].

%% Start application before the suite
init_per_suite(Config) ->
    case application:ensure_all_started(hello_otp) of
        {ok, _StartedApps} ->
            Config;

        {error, Reason} ->
            ct:fail({application_start_failed, Reason})
    end.

%% Stop application after the suite
end_per_suite(_Config) ->
    application:stop(hello_otp),
    ok.

%% Test 1: Application and supervised processes
application_starts(_Config) ->
    assert_true(
        is_pid(whereis(hello_otp_sup)),
        supervisor_started
    ),

    assert_true(
        is_pid(whereis(hello_otp_storage)),
        storage_started
    ),

    assert_true(
        is_pid(whereis(hello_otp_server)),
        counter_server_started
    ),

    assert_true(
        is_pid(whereis(hello_otp_monitor)),
        monitor_started
    ),

    ok.

%% Test 2: Synchronous and asynchronous operations
counter_operations(_Config) ->
    Before = hello_otp_server:get_count(),

    SyncResult = hello_otp_server:increment(),

    assert_equal(
        Before + 1,
        SyncResult,
        synchronous_increment
    ),

    CastResult = hello_otp_server:increment_async(),

    assert_equal(ok, CastResult, asynchronous_cast),

    Current = hello_otp_server:get_count(),

    assert_equal(
        Before + 2,
        Current,
        counter_after_two_increments
    ),

    ok.

%% Test 3: Memory and persistent storage consistency
storage_consistency(_Config) ->
    ServerValue = hello_otp_server:get_count(),
    StoredValue = hello_otp_storage:get_counter(),

    assert_equal(
        ServerValue,
        StoredValue,
        storage_consistency
    ),

    ok.

%% Test 4: Worker restart and monitor reconnection
worker_recovery(_Config) ->
    Before = hello_otp_server:get_count(),
    OldPid = whereis(hello_otp_server),

    MonitorStatus = hello_otp_monitor:get_status(),

    PreviousFailures = maps:get(
        termination_count,
        MonitorStatus
    ),

    %% Deliberately terminate the worker
    exit(OldPid, kill),

    %% Wait for supervisor restart
    NewPid = wait_for_new_worker(OldPid, 50),

    assert_true(
        is_pid(NewPid),
        replacement_worker_started
    ),

    assert_true(
        OldPid =/= NewPid,
        worker_received_new_pid
    ),

    %% Wait for monitoring service to reconnect
    NewStatus = wait_for_monitor(
        NewPid,
        PreviousFailures + 1,
        50
    ),

    assert_equal(
        monitoring,
        maps:get(status, NewStatus),
        monitor_reconnected
    ),

    assert_equal(
        killed,
        maps:get(last_reason, NewStatus),
        termination_reason
    ),

    %% Verify persistent state survived
    assert_equal(
        Before,
        hello_otp_server:get_count(),
        counter_survived_restart
    ),

    assert_equal(
        Before,
        hello_otp_storage:get_counter(),
        persistent_value_survived_restart
    ),

    ok.

%% Wait for replacement worker
wait_for_new_worker(_OldPid, 0) ->
    ct:fail(worker_restart_timeout);

wait_for_new_worker(OldPid, Attempts) ->
    case whereis(hello_otp_server) of
        undefined ->
            timer:sleep(100),
            wait_for_new_worker(OldPid, Attempts - 1);

        OldPid ->
            timer:sleep(100),
            wait_for_new_worker(OldPid, Attempts - 1);

        NewPid ->
            NewPid
    end.

%% Wait for monitoring service to reconnect
wait_for_monitor(_Pid, _Count, 0) ->
    ct:fail(monitor_reconnection_timeout);

wait_for_monitor(Pid, ExpectedCount, Attempts) ->
    Result =
        try hello_otp_monitor:get_status()
        catch
            exit:Reason ->
                {error, Reason}
        end,

    case Result of
        #{
            monitored_pid := Pid,
            termination_count := Count,
            status := monitoring
        } = Status when Count >= ExpectedCount ->
            Status;

        _ ->
            timer:sleep(100),
            wait_for_monitor(Pid, ExpectedCount, Attempts - 1)
    end.

%% Assertion helpers
assert_equal(Expected, Actual, Description) ->
    case Expected =:= Actual of
        true ->
            ok;

        false ->
            ct:fail({
                assertion_failed,
                Description,
                expected,
                Expected,
                actual,
                Actual
            })
    end.

assert_true(true, _Description) ->
    ok;

assert_true(false, Description) ->
    ct:fail({assertion_failed, Description}).
