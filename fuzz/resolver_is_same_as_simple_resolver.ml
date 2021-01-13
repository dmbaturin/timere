open Fuzz_utils

let search_start_dt =
  CCResult.get_exn
  @@ Time.Date_time'.make ~year:2000 ~month:`Jan ~day:1 ~hour:0 ~minute:0
    ~second:0 ~tz:Time_zone.utc

let search_start =
  Time.Date_time'.to_timestamp search_start_dt
  |> Time.Date_time'.min_of_timestamp_local_result
  |> CCOpt.get_exn

let search_end_exc_dt =
  CCResult.get_exn
  @@ Time.Date_time'.make ~year:2003 ~month:`Jan ~day:1 ~hour:0 ~minute:0
    ~second:0 ~tz:Time_zone.utc

let search_end_exc =
  Time.Date_time'.to_timestamp search_end_exc_dt
  |> Time.Date_time'.max_of_timestamp_local_result
  |> CCOpt.get_exn

let () =
  Crowbar.add_test ~name:"resolver_is_same_as_simple_resolver"
    [ time_restricted ] (fun t ->
        Crowbar.check_eq ~eq:(OSeq.equal ~eq:( = ))
          (CCResult.get_exn
           @@ Resolver.resolve
             Time.(
               inter
                 [ t; interval_exact_dt_exc search_start_dt search_end_exc_dt ])
          )
          (Simple_resolver.resolve ~search_start ~search_end_exc
             ~search_using_tz:Time_zone.utc t))
