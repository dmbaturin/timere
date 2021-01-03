open Fuzz_utils

let search_start_dt =
  Result.get_ok
  @@ Time.Date_time.make ~year:0 ~month:`Jan ~day:1 ~hour:0 ~minute:0
    ~second:0 ~tz:Time_zone.utc

let search_start =
  Time.Date_time.to_timestamp search_start_dt
  |> Time.Date_time.min_of_timestamp_local_result
  |> Option.get

let search_end_exc_dt =
  Result.get_ok
  @@ Time.Date_time.make ~year:3 ~month:`Jan ~day:1 ~hour:0 ~minute:0
    ~second:0 ~tz:Time_zone.utc

let search_end_exc =
  Time.Date_time.to_timestamp search_end_exc_dt
  |> Time.Date_time.max_of_timestamp_local_result
  |> Option.get

let () =
  Crowbar.add_test ~name:"resolver_is_same_as_simple_resolver" [ time ]
    (fun t ->
       Crowbar.check_eq ~eq:(OSeq.equal ~eq:( = ))
         (Result.get_ok
          @@ Resolver.resolve
            Time.(
              inter [ t; interval_dt_exc search_start_dt search_end_exc_dt ]))
         (Simple_resolver.resolve ~search_start ~search_end_exc
            ~search_using_tz:Time_zone.utc t))
