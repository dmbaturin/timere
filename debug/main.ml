let default_date_time_format_string =
  "{year} {mon:Xxx} {mday:0X} {wday:Xxx} {hour:0X}:{min:0X}:{sec:0X}"

let default_interval_format_string =
  "[{syear} {smon:Xxx} {smday:0X} {swday:Xxx} {shour:0X}:{smin:0X}:{ssec:0X}, \
   {eyear} {emon:Xxx} {emday:0X} {ewday:Xxx} {ehour:0X}:{emin:0X}:{esec:0X})"

let display_intervals ~display_using_tz s =
  match s () with
  | Seq.Nil -> print_endline "No time intervals"
  | Seq.Cons _ ->
    s
    |> OSeq.take 100
    |> OSeq.iter (fun (x, y) ->
        let s = Printers.sprintf_interval ~display_using_tz (x, y) in
        let size = Duration.of_seconds (Int64.sub y x) in
        let size_str = Printers.sprint_duration size in
        Printf.printf "%s - %s\n" s size_str)

let debug_resolver () =
  (*   let s = {|
   * (unchunk (drop 3 (chunk_at_month_boundary (all))))
   *     |} in
   *   let timere = CCResult.get_exn @@ Of_sexp.of_sexp_string s in *)
  let timere =
    (fun max_height max_branching randomness ->
       let max_height = 1 + max_height in
       let max_branching = 1 + max_branching in
       Builder.build ~enable_extra_restrictions:false ~min_year:2000
         ~max_year_inc:2002 ~max_height ~max_branching ~randomness)
      1 2 [ 738 ]
  in
  (* let timere =
   *   let open Time in
   *   after (Duration.make ~seconds:1 ())
   *     empty
   *     (between_exc (Duration.make ~seconds:10000 ())
   *        (pattern ~hours:[12] ~minutes:[0] ~seconds:[0] ())
   *        (pattern ~hours:[13] ~minutes:[0] ~seconds:[0] ())
   *     )
   * in *)
  (* let timere =
   *   let open Time in
   *   recur
   *     ~year:(every_nth_year 3)
   *     ~month:
   *       (every_nth_month 3)
   *     ~day:(every_nth_day 10)
   *     ( Result.get_ok
   *       @@ Time.Date_time'.make ~year:2000 ~month:`Jan ~day:1 ~hour:0 ~minute:0
   *         ~second:0 ~tz_offset_s:0 )
   * in *)
  (* let tz = Time_zone.make_exn "Australia/Sydney" in *)
  let tz = Time_zone.make_exn "UTC" in
  (* let timere =
   *   let open Time in
   *   with_tz tz
   *     (inter
   *        [
   *          years [ 2020 ];
   *          (\* between_exc (month_days [ -1 ]) (month_days [ 1 ]); *\)
   *          (\* always; *\)
   *          hms_interval_exc
   *            (make_hms_exn ~hour:1 ~minute:15 ~second:0)
   *            (make_hms_exn ~hour:2 ~minute:30 ~second:0);
   *          months [ `Oct ];
   *        ])
   *     (\* (pattern ~months:[`Mar] ~hours:[23] ~minutes:[0] ~seconds:[0]()) *\)
   *     (\* (pattern ~months:[`Mar] ~hours:[4] ~minutes:[30] ~seconds:[0]()) *\)
   * in *)
  print_endline (To_sexp.to_sexp_string timere);
  let search_start_dt =
    Time.Date_time'.make ~year:2000 ~month:`Jan ~day:1 ~hour:10 ~minute:0
      ~second:0 ~tz
    |> CCResult.get_exn
  in
  let search_start =
    Time.Date_time'.to_timestamp search_start_dt
    |> Time.Date_time'.min_of_timestamp_local_result
    |> CCOpt.get_exn
  in
  let search_end_exc_dt =
    Time.Date_time'.make ~year:2003 ~month:`Jan ~day:1 ~hour:0 ~minute:0
      ~second:0 ~tz
    |> CCResult.get_exn
  in
  let search_end_exc =
    Time.Date_time'.to_timestamp search_end_exc_dt
    |> Time.Date_time'.max_of_timestamp_local_result
    |> CCOpt.get_exn
  in
  let timere' =
    Time.(inter [ timere; interval_exact_exc search_start search_end_exc ])
  in
  print_endline "^^^^^";
  print_endline (To_sexp.to_sexp_string timere');
  print_endline "=====";
  (match Resolver.resolve timere' with
   | Error msg -> print_endline msg
   | Ok s -> display_intervals ~display_using_tz:tz s);
  print_endline "=====";
  let s =
    Simple_resolver.resolve ~search_start ~search_end_exc
      ~search_using_tz:Time_zone.utc timere
  in
  display_intervals ~display_using_tz:tz s;
  print_newline ()

let debug_ccsexp_parse_string () = CCSexp.parse_string "\"\\256\"" |> ignore

let debug_example () =
  let display_intervals ~display_using_tz s =
    match s () with
    | Seq.Nil -> print_endline "No time intervals"
    | Seq.Cons _ ->
      s
      |> OSeq.take 60
      |> OSeq.iter (fun (x, y) ->
          let s = Printers.sprintf_interval ~display_using_tz (x, y) in
          let size = Duration.of_seconds (Int64.sub y x) in
          let size_str = Printers.sprint_duration size in
          Printf.printf "%s - %s\n" s size_str)
  in
  let open Time in
  let open Infix in
  (* let tz = Time_zone.make_exn "Australia/Sydney" in *)
  let tz = Time_zone.utc in
  let first_weekday_of_month wday =
    follow (Duration.make ~days:7 ()) (month_days [ 1 ]) (weekdays [ wday ])
  in
  let second_weekday_of_month wday =
    shift (Duration.make ~days:7 ()) (first_weekday_of_month wday)
  in
  let third_weekday_of_month wday =
    shift (Duration.make ~days:14 ()) (first_weekday_of_month wday)
  in
  let fourth_weekday_of_month wday =
    shift (Duration.make ~days:21 ()) (first_weekday_of_month wday)
  in
  let fifth_weekday_of_month wday =
    follow (Duration.make ~days:7 ())
      (shift (Duration.make ~days:1 ()) (fourth_weekday_of_month wday))
      (interval_inc (Duration.make ~days:7 ())
         (month_days [ -7 ])
         (month_days [ -1 ])
       & weekdays [ wday ])
  in
  let search_start_dt =
    Time.Date_time'.make ~year:2000 ~month:`Jan ~day:1 ~hour:10 ~minute:0
      ~second:0 ~tz
    |> CCResult.get_exn
  in
  let search_start =
    Time.Date_time'.to_timestamp search_start_dt
    |> Time.Date_time'.min_of_timestamp_local_result
    |> CCOpt.get_exn
  in
  let search_end_exc_dt =
    Time.Date_time'.make ~year:2022 ~month:`Jan ~day:1 ~hour:0 ~minute:0
      ~second:0 ~tz
    |> CCResult.get_exn
  in
  let search_end_exc =
    Time.Date_time'.to_timestamp search_end_exc_dt
    |> Time.Date_time'.max_of_timestamp_local_result
    |> CCOpt.get_exn
  in
  let timere =
    (* (interval_exact_exc search_start search_end_exc)
     * & *)
    years [ 2021 ] & fifth_weekday_of_month `Fri
  in
  match Resolver.resolve timere with
  | Error msg -> print_endline msg
  | Ok s -> display_intervals ~display_using_tz:tz s

let debug_fuzz_after () =
  let bound = Int64.of_int 57633 in
  print_endline (Duration.(of_seconds bound) |> Printers.sprint_duration);
  let tz = Time_zone.utc in
  let t1 =
    (fun max_height max_branching randomness ->
       let max_height = 1 + max_height in
       let max_branching = 1 + max_branching in
       Builder.build ~enable_extra_restrictions:false ~min_year:2000
         ~max_year_inc:2002 ~max_height ~max_branching ~randomness)
      1 3
      [ 882; 891; 595; 891; 891 ]
  in
  let t2 =
    (fun max_height max_branching randomness ->
       let max_height = 1 + max_height in
       let max_branching = 1 + max_branching in
       Builder.build ~enable_extra_restrictions:false ~min_year:2000
         ~max_year_inc:2002 ~max_height ~max_branching ~randomness)
      0 3
      [ 891; 891; 891; 926; 907 ]
  in
  let t1' = Resolver.t_of_ast t1 in
  let t2' = Resolver.t_of_ast t2 in
  let s1 = Resolver.aux tz t1' in
  let s2 = Resolver.aux tz t2' in
  let l1 = CCList.of_seq s1 in
  let l2 = CCList.of_seq s2 in
  let s = Resolver.(aux_follow tz default_search_space bound s1 s2 t1' t2') in
  print_endline "=====";
  print_endline (To_sexp.to_sexp_string t1);
  display_intervals ~display_using_tz:tz s1;
  print_endline "=====";
  print_endline (To_sexp.to_sexp_string t2);
  display_intervals ~display_using_tz:tz s2;
  print_endline "=====";
  display_intervals ~display_using_tz:tz s;
  print_endline "=====";
  Printf.printf "%b\n"
    (OSeq.for_all
       (fun (x, _y) ->
          match
            List.filter (fun (x1, _y1) -> x1 <= x && Int64.sub x x1 <= bound) l1
          with
          | [] ->
            print_endline "test";
            false
          | r ->
            let xr, _yr = List.hd @@ List.rev r in
            not (OSeq.exists (fun (x2, _y2) -> xr <= x2 && x2 < x) s2))
       s)

let debug_fuzz_between_exc () =
  let bound = Int64.of_int 8904 in
  let tz = Time_zone.utc in
  let t1 =
    (fun max_height max_branching randomness ->
       let max_height = 1 + max_height in
       let max_branching = 1 + max_branching in
       Builder.build ~enable_extra_restrictions:false ~min_year:2000
         ~max_year_inc:2002 ~max_height ~max_branching ~randomness)
      0 3
      [ 143; 143; 143; 143; 109 ]
  in
  let t2 =
    (fun max_height max_branching randomness ->
       let max_height = 1 + max_height in
       let max_branching = 1 + max_branching in
       Builder.build ~enable_extra_restrictions:false ~min_year:2000
         ~max_year_inc:2002 ~max_height ~max_branching ~randomness)
      1 3 [ 713 ]
  in
  let t1' = Resolver.t_of_ast t1 in
  let t2' = Resolver.t_of_ast t2 in
  let s1 = Resolver.aux tz t1' in
  let s2 = Resolver.aux tz t2' in
  let l1 = CCList.of_seq s1 in
  let l2 = CCList.of_seq s2 in
  let s = Resolver.(aux_follow tz default_search_space bound s1 s2 t1' t2') in
  print_endline "=====";
  display_intervals ~display_using_tz:tz s1;
  print_endline (To_sexp.to_sexp_string t1);
  print_endline "=====";
  display_intervals ~display_using_tz:tz s2;
  print_endline (To_sexp.to_sexp_string t2);
  print_endline "=====";
  display_intervals ~display_using_tz:tz s;
  print_endline "=====";
  Printf.printf "%b\n"
    (OSeq.for_all
       (fun (x, y) ->
          match List.filter (fun (x1, _y1) -> x = x1) l1 with
          | [] -> false
          | [ (_xr1, yr1) ] -> (
              match List.filter (fun (x2, y2) -> y = y2) l2 with
              | [] -> false
              | [ (xr2, _yr2) ] ->
                not (List.exists (fun (x2, _y2) -> yr1 <= x2 && x2 < xr2) l2)
              | _ -> false)
          | _ -> false)
       s)

let debug_fuzz_union () =
  let tz = Time_zone.utc in
  let t1 =
    (fun max_height max_branching randomness ->
       let max_height = 1 + max_height in
       let max_branching = 1 + max_branching in
       Builder.build ~enable_extra_restrictions:false ~min_year:2000
         ~max_year_inc:2002 ~max_height ~max_branching ~randomness)
      0 3 [ 761; 143 ]
  in
  let t2 =
    (fun max_height max_branching randomness ->
       let max_height = 1 + max_height in
       let max_branching = 1 + max_branching in
       Builder.build ~enable_extra_restrictions:false ~min_year:2000
         ~max_year_inc:2002 ~max_height ~max_branching ~randomness)
      1 0 [ 113 ]
  in
  let t1' = Resolver.t_of_ast t1 in
  let t2' = Resolver.t_of_ast t2 in
  let s1 = Resolver.aux tz t1' |> Resolver.normalize in
  let s2 = Resolver.aux tz t2' in
  let l = [ t1' ] in
  let s' =
    l
    |> List.map (Resolver.aux tz)
    |> CCList.to_seq
    |> Time.Intervals.Union.union_multi_seq
    |> Time.Intervals.Slice.slice ~start:Time.min_timestamp
      ~end_exc:Time.max_timestamp
  in
  let s = Resolver.aux_union tz (CCList.to_seq l) |> Resolver.normalize in
  print_endline "=====";
  display_intervals ~display_using_tz:tz s1;
  print_endline (To_sexp.to_sexp_string t1);
  (* print_endline "=====";
   * display_intervals ~display_using_tz:tz s2;
   * print_endline (To_sexp.to_sexp_string t2); *)
  print_endline "=====";
  display_intervals ~display_using_tz:tz s';
  print_endline "=====";
  display_intervals ~display_using_tz:tz s;
  print_endline "=====";
  Printf.printf "%b\n" (OSeq.equal ~eq:( = ) s s')

(* let () = debug_branching () *)

(* let () = debug_parsing () *)

(* let () = debug_resolver () *)

(* let () = debug_ccsexp_parse_string () *)

let () = debug_example ()

(* let () = debug_fuzz_after () *)

(* let () = debug_fuzz_between_exc () *)

(* let () = debug_fuzz_union () *)
