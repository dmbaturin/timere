open Date_components

module Print_utils = struct
  let small_nat = QCheck.Print.int

  let int64 = Int64.to_string

  let time_slot = QCheck.Print.pair int64 int64

  let time_slots = QCheck.Print.list time_slot
end

let nz_small_nat_gen = QCheck.Gen.(map (( + ) 1) small_nat)

let nz_small_nat = QCheck.make nz_small_nat_gen

let int64_bound_gen bound =
  let open QCheck.Gen in
  map
    (fun (pos, x) ->
       x |> max 0L |> min bound |> fun x -> if pos then x else Int64.mul (-1L) x)
    (pair bool ui64)

let pos_int64_bound_gen bound =
  QCheck.Gen.(map (fun x -> x |> max 0L |> min bound) ui64)

let nz_pos_int64_bound_gen bound =
  QCheck.Gen.(map (fun x -> x |> max 1L |> min bound) ui64)

let small_pos_int64_gen = pos_int64_bound_gen 100L

let small_nz_pos_int64_gen = nz_pos_int64_bound_gen 100L

let int64_gen = int64_bound_gen (Int64.sub Int64.max_int 1L)

let pos_int64_gen = pos_int64_bound_gen (Int64.sub Int64.max_int 1L)

let pos_int64 = QCheck.make ~print:Print_utils.int64 pos_int64_gen

let small_pos_int64 = QCheck.make ~print:Print_utils.int64 small_pos_int64_gen

let small_nz_pos_int64 =
  QCheck.make ~print:Print_utils.int64 small_nz_pos_int64_gen

let nz_pos_int64_gen =
  QCheck.Gen.map (Int64.add 1L)
    (pos_int64_bound_gen (Int64.sub Int64.max_int 1L))

let nz_pos_int64 = QCheck.make ~print:Print_utils.int64 nz_pos_int64_gen

let pos_int64_int64_option_bound_gen bound =
  QCheck.Gen.(
    pair (pos_int64_bound_gen bound) (opt (pos_int64_bound_gen bound)))

let nz_pos_int64_int64_option_bound_gen bound =
  let open QCheck.Gen in
  pair (nz_pos_int64_bound_gen bound) (opt (nz_pos_int64_bound_gen bound))

let small_pos_int64_int64_option_gen =
  QCheck.Gen.(pair small_pos_int64_gen (opt small_pos_int64_gen))

let small_nz_pos_int64_int64_option_gen =
  QCheck.Gen.(pair small_nz_pos_int64_gen (opt small_nz_pos_int64_gen))

let pos_int64_int64_option_gen =
  QCheck.Gen.(pair pos_int64_gen (opt pos_int64_gen))

let nz_pos_int64_int64_option_gen =
  nz_pos_int64_int64_option_bound_gen (Int64.sub Int64.max_int 1L)

let tiny_sorted_time_slots_gen =
  let open QCheck.Gen in
  map
    (fun (start, sizes_and_gaps) ->
       sizes_and_gaps
       |> List.fold_left
         (fun (last_end_exc, acc) (size, gap) ->
            let start =
              match last_end_exc with
              | None -> start
              | Some x -> Int64.add x gap
            in
            let end_exc = Int64.add start size in
            (Some end_exc, (start, end_exc) :: acc))
         (None, [])
       |> fun (_, l) -> List.rev l)
    (pair (int64_bound_gen 10_000L)
       (list_size (int_bound 5)
          (pair (pos_int64_bound_gen 20L) (pos_int64_bound_gen 20L))))

let tiny_sorted_time_slots =
  QCheck.make ~print:Print_utils.time_slots tiny_sorted_time_slots_gen

let sorted_time_slots_maybe_gaps_gen =
  let open QCheck.Gen in
  map
    (fun (start, sizes_and_gaps) ->
       sizes_and_gaps
       |> List.fold_left
         (fun (last_end_exc, acc) (size, gap) ->
            let start =
              match last_end_exc with
              | None -> start
              | Some x -> Int64.add x (Int64.of_int gap)
            in
            let end_exc = Int64.add start (Int64.of_int size) in
            (Some end_exc, (start, end_exc) :: acc))
         (None, [])
       |> fun (_, l) -> List.rev l)
    (pair int64_gen
       (list_size (int_bound 1000) (pair nz_small_nat_gen small_nat)))

let sorted_time_slots_maybe_gaps =
  QCheck.make ~print:Print_utils.time_slots sorted_time_slots_maybe_gaps_gen

let sorted_time_slots_with_gaps_gen =
  let open QCheck.Gen in
  map
    (fun (start, sizes_and_gaps) ->
       sizes_and_gaps
       |> List.fold_left
         (fun (last_end_exc, acc) (size, gap) ->
            let start =
              match last_end_exc with
              | None -> start
              | Some x -> Int64.add x (Int64.of_int gap)
            in
            let end_exc = Int64.add start (Int64.of_int size) in
            (Some end_exc, (start, end_exc) :: acc))
         (None, [])
       |> fun (_, l) -> List.rev l)
    (pair int64_gen
       (list_size (int_bound 1000) (pair nz_small_nat_gen nz_small_nat_gen)))

let sorted_time_slots_with_gaps =
  QCheck.make ~print:Print_utils.time_slots sorted_time_slots_with_gaps_gen

let sorted_time_slots_with_overlaps_gen =
  let open QCheck.Gen in
  map
    (fun (start, sizes_and_gaps) ->
       sizes_and_gaps
       |> List.fold_left
         (fun (last_start_and_size, acc) (size, gap) ->
            let start, size =
              match last_start_and_size with
              | None -> (start, Int64.of_int size)
              | Some (last_start, last_size) ->
                let start = Int64.add last_start (Int64.of_int gap) in
                let size =
                  if start = last_start then
                    Int64.add last_size (Int64.of_int size)
                  else Int64.of_int size
                in
                (start, size)
            in
            let end_exc = Int64.add start size in
            (Some (start, size), (start, end_exc) :: acc))
         (None, [])
       |> fun (_, l) -> List.rev l)
    (pair int64_gen
       (list_size (int_bound 1000) (pair nz_small_nat_gen small_nat)))

let sorted_time_slots_with_overlaps =
  QCheck.make ~print:Print_utils.time_slots sorted_time_slots_with_overlaps_gen

let tiny_time_slots_gen =
  let open QCheck.Gen in
  map
    (List.map (fun (start, size) -> (start, Int64.add start size)))
    (list_size (int_bound 5)
       (pair (int64_bound_gen 10_000L) (pos_int64_bound_gen 20L)))

let tiny_time_slots =
  QCheck.make ~print:Print_utils.time_slots tiny_time_slots_gen

let time_slots_gen =
  let open QCheck.Gen in
  map
    (List.map (fun (start, size) ->
         (start, Int64.add start (Int64.of_int size))))
    (list_size (int_bound 100) (pair (int64_bound_gen 100_000L) small_nat))

let time_slots = QCheck.make ~print:Print_utils.time_slots time_slots_gen

let weekday_gen : weekday QCheck.Gen.t =
  QCheck.Gen.(oneofl [ `Sun; `Mon; `Tue; `Wed; `Thu; `Fri; `Sat ])

let month_gen : month QCheck.Gen.t =
  let open QCheck.Gen in
  oneofl
    [ `Jan; `Feb; `Mar; `Apr; `May; `Jun; `Jul; `Aug; `Sep; `Oct; `Nov; `Dec ]

let month_days_gen : int list QCheck.Gen.t =
  QCheck.Gen.(list_size (int_bound 10) (int_range 1 32))

let month_days = QCheck.make ~print:QCheck.Print.(list int) month_days_gen

let weekdays_gen : weekday list QCheck.Gen.t =
  QCheck.Gen.(list_size (int_bound 10) weekday_gen)

let weekdays =
  QCheck.make
    ~print:(QCheck.Print.list Time.abbr_string_of_weekday)
    weekdays_gen

(* let time_pattern_gen : Time_pattern.time_pattern QCheck.Gen.t =
 *   let open QCheck.Gen in
 *   map
 *     (fun (years, months, month_days, (weekdays, hours, minutes, seconds)) ->
 *        let open Daypack_lib.Time_pattern in
 *        {
 *          years;
 *          months;
 *          month_days;
 *          weekdays;
 *          hours;
 *          minutes;
 *          seconds;
 *          unix_seconds = [];
 *        })
 *     (quad
 *        (list_size (int_bound 5) (int_range 1980 2100))
 *        (list_size (int_bound 5) month_gen)
 *        month_days_gen
 *        (quad weekdays_gen
 *           (list_size (int_bound 5) (int_bound 24))
 *           (list_size (int_bound 5) (int_bound 60))
 *           (list_size (int_bound 5) (int_bound 60)))) *)

let default_date_time_format_string =
  "{year} {mon:Xxx} {mday:0X} {wday:Xxx} {hour:0X}:{min:0X}:{sec:0X}"

let default_interval_format_string =
  "[{syear} {smon:Xxx} {smday:0X} {swday:Xxx} {shour:0X}:{smin:0X}:{ssec:0X}, \
   {eyear} {emon:Xxx} {emday:0X} {ewday:Xxx} {ehour:0X}:{emin:0X}:{esec:0X})"

let date_time_testable : (module Alcotest.TESTABLE) =
  (module struct
    type t = Time.Date_time'.t

    let pp formatter t = Printers.pp_date_time formatter t

    let equal = Time.Date_time'.equal
  end)

let tz_testable : (module Alcotest.TESTABLE with type t = Time_zone.t) =
  (module struct
    type t = Time_zone.t

    let pp _formatter _t = failwith "Time zone is not printable"

    let equal = Time_zone.equal
  end)

(* let time_pattern_testable : (module Alcotest.TESTABLE) =
 *   ( module struct
 *     type t = Daypack_lib.Time_pattern.time_pattern
 * 
 *     let pp =
 *       Fmt.using Daypack_lib.Time_pattern.To_string.debug_string_of_time_pattern
 *         Fmt.string
 * 
 *     let equal = ( = )
 *   end ) *)

let time_gen : Time_ast.t QCheck.Gen.t =
  let open QCheck.Gen in
  let search_start_dt =
    CCResult.get_exn
    @@ Time.Date_time'.make ~year:2018 ~month:`Jan ~day:1 ~hour:0 ~minute:0
      ~second:0 ~tz:Time_zone.utc
  in
  let search_end_exc_dt =
    CCResult.get_exn
    @@ Time.Date_time'.make ~year:2021 ~month:`Jan ~day:1 ~hour:0 ~minute:0
      ~second:0 ~tz:Time_zone.utc
  in
  map3
    (fun max_height max_branching randomness ->
       Time.inter
         [
           Time.(interval_exact_dt_exc search_start_dt search_end_exc_dt);
           Builder.build ~enable_extra_restrictions:true ~min_year:2018
             ~max_year_inc:2020 ~max_height ~max_branching ~randomness;
         ])
    (int_range 1 2) (int_range 1 3)
    (list_size (int_bound 10) (int_bound 100))

let time = QCheck.make ~print:To_sexp.to_sexp_string time_gen

let time_list_gen n : Time_ast.t list QCheck.Gen.t =
  let open QCheck.Gen in
  list_size (int_bound n) time_gen

let time_list n =
  QCheck.make
    ~print:(fun l -> String.concat ", " (List.map To_sexp.to_sexp_string l))
    (time_list_gen n)

let time_zone_gen : Time_zone.t QCheck.Gen.t =
  let open QCheck.Gen in
  let tz_count = List.length Time_zone.available_time_zones in
  map
    (fun n -> Time_zone.make_exn (List.nth Time_zone.available_time_zones n))
    (int_bound (tz_count - 1))

let time_zone =
  QCheck.make ~print:(fun (t : Time_zone.t) -> t.name) time_zone_gen

let permute (seed : int) (l : 'a list) : 'a list =
  let len = List.length l in
  let l = ref l in
  OSeq.(0 --^ len)
  |> Seq.map (fun i ->
      let l' = List.mapi (fun i x -> (i, x)) !l in
      let len = List.length l' in
      let pick = i * seed mod len in
      let r = List.assoc pick l' in
      l := List.remove_assoc pick l' |> List.map (fun (_, x) -> x);
      r)
  |> CCList.of_seq
