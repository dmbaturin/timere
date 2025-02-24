open Date_time_components

let sexp_of_month x = CCSexp.atom @@ Time.abbr_string_of_month x

let sexp_of_weekday x = CCSexp.atom @@ Time.abbr_string_of_weekday x

let sexp_of_int64 x = CCSexp.atom @@ Int64.to_string x

let sexp_of_int x = CCSexp.atom @@ string_of_int x

let sexp_list_of_ints l = List.map sexp_of_int l

let sexp_of_tz_name t = CCSexp.atom (Time_zone.name t)

let sexp_of_span (x : Span.t) =
  CCSexp.list [ sexp_of_int64 x.s; sexp_of_int x.ns ]

let sexp_of_tz_info info =
  let open CCSexp in
  list
    (match info with
     | `Tz_only x -> [ atom "tz"; sexp_of_tz_name x ]
     | `Tz_offset_s_only x -> [ atom "tz_offset_s"; sexp_of_int x ]
     | `Tz_and_tz_offset_s (tz, tz_offset_s) ->
       [
         atom "tz_and_tz_offset_s"; sexp_of_tz_name tz; sexp_of_int tz_offset_s;
       ])

let sexp_of_points (pick, tz_info) =
  let open CCSexp in
  let open Points in
  list
    (CCList.filter_map CCFun.id
       [
         Some (atom "points");
         Some
           (list
              (atom "pick"
               ::
               (match pick with
                | S x -> [ atom "s"; sexp_of_int x ]
                | MS { minute; second } ->
                  [ atom "ms"; sexp_of_int minute; sexp_of_int second ]
                | HMS { hour; minute; second } ->
                  [
                    atom "hms";
                    sexp_of_int hour;
                    sexp_of_int minute;
                    sexp_of_int second;
                  ]
                | WHMS { weekday; hour; minute; second } ->
                  [
                    atom "whms";
                    sexp_of_weekday weekday;
                    sexp_of_int hour;
                    sexp_of_int minute;
                    sexp_of_int second;
                  ]
                | DHMS { month_day; hour; minute; second } ->
                  [
                    atom "dhms";
                    sexp_of_int month_day;
                    sexp_of_int hour;
                    sexp_of_int minute;
                    sexp_of_int second;
                  ]
                | MDHMS { month; month_day; hour; minute; second } ->
                  [
                    atom "mdhms";
                    sexp_of_month month;
                    sexp_of_int month_day;
                    sexp_of_int hour;
                    sexp_of_int minute;
                    sexp_of_int second;
                  ]
                | YMDHMS { year; month; month_day; hour; minute; second } ->
                  [
                    atom "ymdhms";
                    sexp_of_int year;
                    sexp_of_month month;
                    sexp_of_int month_day;
                    sexp_of_int hour;
                    sexp_of_int minute;
                    sexp_of_int second;
                  ])));
         CCOpt.map sexp_of_tz_info tz_info;
       ])

let sexp_of_date_time (x : Time.Date_time'.t) =
  let open CCSexp in
  list
    [
      sexp_of_int x.year;
      sexp_of_month x.month;
      sexp_of_int x.day;
      sexp_of_int x.hour;
      sexp_of_int x.minute;
      sexp_of_int x.second;
      sexp_of_int x.ns;
      sexp_of_tz_info x.tz_info;
    ]

let sexp_of_duration (x : Duration.t) =
  let open CCSexp in
  list
    [
      atom "duration";
      sexp_of_int x.days;
      sexp_of_int x.hours;
      sexp_of_int x.minutes;
      sexp_of_int x.seconds;
    ]

let sexp_of_timestamp x =
  x
  |> Time.Date_time'.of_timestamp ~tz_of_date_time:Time_zone.utc
  |> CCOpt.get_exn
  |> sexp_of_date_time

let sexp_of_range ~(f : 'a -> CCSexp.t) (r : 'a Time.Range.range) =
  match r with
  | `Range_inc (x, y) -> CCSexp.(list [ atom "range_inc"; f x; f y ])
  | `Range_exc (x, y) -> CCSexp.(list [ atom "range_exc"; f x; f y ])

let sexp_of_pattern (pat : Pattern.t) : CCSexp.t =
  let years =
    pat.years |> Int_set.to_seq |> CCList.of_seq |> sexp_list_of_ints
  in
  let months =
    pat.months |> Month_set.to_seq |> CCList.of_seq |> List.map sexp_of_month
  in
  let month_days =
    pat.month_days |> Int_set.to_seq |> CCList.of_seq |> sexp_list_of_ints
  in
  let weekdays =
    pat.weekdays
    |> Weekday_set.to_seq
    |> CCList.of_seq
    |> List.map sexp_of_weekday
  in
  let hours =
    pat.hours |> Int_set.to_seq |> CCList.of_seq |> sexp_list_of_ints
  in
  let minutes =
    pat.minutes |> Int_set.to_seq |> CCList.of_seq |> sexp_list_of_ints
  in
  let seconds =
    pat.seconds |> Int_set.to_seq |> CCList.of_seq |> sexp_list_of_ints
  in
  let open CCSexp in
  [
    Some (atom "pattern");
    (match years with [] -> None | _ -> Some (list (atom "years" :: years)));
    (match months with
     | [] -> None
     | _ -> Some (list (atom "months" :: months)));
    (match month_days with
     | [] -> None
     | _ -> Some (list (atom "month_days" :: month_days)));
    (match weekdays with
     | [] -> None
     | _ -> Some (list (atom "weekdays" :: weekdays)));
    (match hours with [] -> None | _ -> Some (list (atom "hours" :: hours)));
    (match minutes with
     | [] -> None
     | _ -> Some (list (atom "minutes" :: minutes)));
    (match seconds with
     | [] -> None
     | _ -> Some (list (atom "seconds" :: seconds)));
  ]
  |> CCList.filter_map CCFun.id
  |> list

let sexp_list_of_unary_op (op : Time_ast.unary_op) =
  match op with
  | Not -> [ CCSexp.atom "not" ]
  (* | Drop_points n ->
   *   [ CCSexp.atom "drop_points"; CCSexp.atom (string_of_int n) ]
   * | Take_points n ->
   *   [ CCSexp.atom "take_points"; CCSexp.atom (string_of_int n) ] *)
  (* | Every_nth n -> [ CCSexp.atom "every_nth"; CCSexp.atom (string_of_int n) ]
   * | Nth n -> [ CCSexp.atom "nth"; CCSexp.atom (string_of_int n) ]
   * | Chunk { chunk_size; drop_partial } ->
   *   [
   *     Some (CCSexp.atom "chunk");
   *     (if drop_partial then Some (CCSexp.atom "drop_partial") else None);
   *     Some (CCSexp.atom (Int64.to_string chunk_size));
   *   ]
   *   |> List.filter_map Fun.id
   * | Chunk_by_year -> [ CCSexp.atom "chunk_by_year"]
   * | Chunk_by_month -> [ CCSexp.atom "chunk_by_month"] *)
  | Shift n -> [ CCSexp.atom "shift"; sexp_of_span n ]
  | Lengthen n -> [ CCSexp.atom "lengthen"; sexp_of_span n ]
  | With_tz tz -> [ CCSexp.atom "with_tz"; CCSexp.atom (Time_zone.name tz) ]

let to_sexp (t : Time_ast.t) : CCSexp.t =
  let rec aux (t : Time_ast.t) =
    match t with
    | All -> CCSexp.(list [ atom "all" ])
    | Empty -> CCSexp.(list [ atom "empty" ])
    | Intervals s ->
      let l =
        s
        |> CCList.of_seq
        |> List.map (fun (x, y) ->
            CCSexp.list [ sexp_of_timestamp x; sexp_of_timestamp y ])
      in
      CCSexp.list (CCSexp.atom "intervals" :: l)
    | Pattern pat -> sexp_of_pattern pat
    | Unary_op (op, t) -> CCSexp.list (sexp_list_of_unary_op op @ [ aux t ])
    | Inter_seq s ->
      CCSexp.(list (atom "inter" :: (s |> Seq.map aux |> CCList.of_seq)))
    | Union_seq s ->
      CCSexp.(list (atom "union" :: (s |> Seq.map aux |> CCList.of_seq)))
    | Bounded_intervals { pick; bound; start; end_exc } ->
      CCSexp.(
        list
          [
            atom "bounded_intervals";
            (match pick with `Whole -> atom "whole" | `Snd -> atom "snd");
            sexp_of_span bound;
            sexp_of_points start;
            sexp_of_points end_exc;
          ])
    | Unchunk chunked -> CCSexp.(list [ atom "unchunk"; aux_chunked chunked ])
  and aux_chunked chunked =
    let sexp_list_of_unary_op_on_t op =
      let open CCSexp in
      match op with
      | Time_ast.Chunk_disjoint_interval -> [ atom "chunk_disjoint_intervals" ]
      | Chunk_at_year_boundary -> [ atom "chunk_at_year_boundary" ]
      | Chunk_at_month_boundary -> [ atom "chunk_at_month_boundary" ]
      | Chunk_by_duration { chunk_size; drop_partial } ->
        [
          Some (atom "chunk_by_duration");
          Some (sexp_of_span chunk_size);
          (if drop_partial then Some (atom "drop_partial") else None);
        ]
        |> CCList.filter_map CCFun.id
    in
    match chunked with
    | Unary_op_on_t (op, t) ->
      CCSexp.(list (sexp_list_of_unary_op_on_t op @ [ aux t ]))
    | Unary_op_on_chunked (op, chunked) ->
      CCSexp.(
        list
          (match op with
           | Drop n -> [ atom "drop"; sexp_of_int n; aux_chunked chunked ]
           | Take n -> [ atom "take"; sexp_of_int n; aux_chunked chunked ]
           | Take_nth n ->
             [ atom "take_nth"; sexp_of_int n; aux_chunked chunked ]
           | Nth n -> [ atom "nth"; sexp_of_int n; aux_chunked chunked ]
           | Chunk_again op ->
             [
               atom "chunk_again";
               list (sexp_list_of_unary_op_on_t op @ [ aux_chunked chunked ]);
             ]))
  in
  aux t

let wrap_to_sexp_into_to_sexp_string (f : 'a -> CCSexp.t) x =
  CCSexp.to_string (f x)

let to_sexp_string = wrap_to_sexp_into_to_sexp_string to_sexp
