open Test_utils

module Alco = struct
  let leap_second0 () =
    Alcotest.(check span_testable)
      "same timestamp"
      (Time.Date_time'.make_exn ~tz:Time_zone.utc ~year:2020 ~month:`Jan ~day:1
         ~hour:0 ~minute:0 ~second:60 ~ns:1_000_000 ()
       |> Time.Date_time'.to_timestamp_single)
      (Time.Date_time'.make_exn ~tz:Time_zone.utc ~year:2020 ~month:`Jan ~day:1
         ~hour:0 ~minute:0 ~second:59 ~ns:1_000_000 ()
       |> Time.Date_time'.to_timestamp_single)

  let of_iso8601_leap_second0 () =
    Alcotest.(check span_testable)
      "same timestamp"
      (CCResult.get_exn @@ ISO8601.to_timestamp "2020-01-01T00:00:60.001Z")
      (Time.Date_time'.make_exn ~tz:Time_zone.utc ~year:2020 ~month:`Jan ~day:1
         ~hour:0 ~minute:0 ~second:60 ~ns:1_000_000 ()
       |> Time.Date_time'.to_timestamp_single)

  let of_iso8601_leap_second1 () =
    Alcotest.(check span_testable)
      "same timestamp"
      (CCResult.get_exn @@ ISO8601.to_timestamp "2020-01-01T00:00:60.1Z")
      (Time.Date_time'.make_exn ~tz:Time_zone.utc ~year:2020 ~month:`Jan ~day:1
         ~hour:0 ~minute:0 ~second:60 ~ns:100_000_000 ()
       |> Time.Date_time'.to_timestamp_single)

  let of_iso8601_leap_second_to_rfc3339_case0 () =
    Alcotest.(check string)
      "same timestamp" "2020-01-01T00:00:60Z"
      (ISO8601.to_date_time "2020-01-01T00:00:60Z"
       |> CCResult.get_exn
       |> RFC3339.of_date_time
       |> CCOpt.get_exn)

  let of_iso8601_leap_second_to_rfc3339_case1 () =
    Alcotest.(check string)
      "same timestamp" "2020-01-01T00:00:60.12305Z"
      (ISO8601.to_date_time "2020-01-01T00:00:60.12305Z"
       |> CCResult.get_exn
       |> RFC3339.of_date_time
       |> CCOpt.get_exn)

  let of_iso8601_case0 () =
    Alcotest.(check span_testable)
      "same timestamp"
      (CCResult.get_exn @@ ISO8601.to_timestamp "2020-01-01T24:00:00Z")
      (Time.Date_time'.make_exn ~tz:Time_zone.utc ~year:2020 ~month:`Jan ~day:1
         ~hour:23 ~minute:59 ~second:59 ~ns:999_999_999 ()
       |> Time.Date_time'.to_timestamp_single)

  let suite =
    [
      Alcotest.test_case "leap_second0" `Quick leap_second0;
      Alcotest.test_case "of_iso8601_leap_second0" `Quick
        of_iso8601_leap_second0;
      Alcotest.test_case "of_iso8601_leap_second1" `Quick
        of_iso8601_leap_second1;
      Alcotest.test_case "of_iso8601_leap_second_to_rfc3339_case0" `Quick
        of_iso8601_leap_second_to_rfc3339_case0;
      Alcotest.test_case "of_iso8601_leap_second_to_rfc3339_case1" `Quick
        of_iso8601_leap_second_to_rfc3339_case1;
      Alcotest.test_case "of_iso8601_case0" `Quick of_iso8601_case0;
    ]
end

module Qc = struct
  let to_rfc3339_nano_of_iso8601_is_lossless =
    QCheck.Test.make ~count:100_000
      ~name:"to_rfc3339_nano_of_iso8601_is_lossless" timestamp (fun timestamp ->
          let r =
            CCResult.get_exn
            @@ ISO8601.to_timestamp
            @@ RFC3339.of_timestamp ~frac_s:9 timestamp
          in
          Span.equal r timestamp)

  let to_rfc3339_w_default_frac_s_of_iso8601_is_lossless =
    QCheck.Test.make ~count:100_000
      ~name:"to_rfc3339_w_default_frac_s_of_iso8601_is_lossless" timestamp
      (fun timestamp ->
         let r =
           CCResult.get_exn
           @@ ISO8601.to_timestamp
           @@ RFC3339.of_timestamp timestamp
         in
         Span.equal r timestamp)

  let to_rfc3339_of_iso8601_is_accurate =
    QCheck.Test.make ~count:100_000 ~name:"to_rfc3339_of_iso8601_is_accurate"
      QCheck.(pair (int_bound 9) timestamp)
      (fun (frac_s, timestamp) ->
         let r =
           CCResult.get_exn
           @@ ISO8601.to_timestamp
           @@ RFC3339.of_timestamp ~frac_s timestamp
         in
         Span.(
           abs (r - timestamp)
           < make ~s:0L
             ~ns:(int_of_float (10. ** float_of_int (CCInt.sub 9 frac_s)))
             ()))

  let of_to_timestamp =
    QCheck.Test.make ~count:100_000 ~name:"of_to_timestamp"
      QCheck.(pair time_zone timestamp)
      (fun (tz, timestamp) ->
         let r =
           Time.Date_time'.to_timestamp_single
           @@ CCOpt.get_exn
           @@ Time.Date_time'.of_timestamp ~tz_of_date_time:tz timestamp
         in
         Span.equal r timestamp)

  let suite =
    [
      to_rfc3339_nano_of_iso8601_is_lossless;
      to_rfc3339_w_default_frac_s_of_iso8601_is_lossless;
      to_rfc3339_of_iso8601_is_accurate;
      of_to_timestamp;
    ]
end
