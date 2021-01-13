open Date_components

let timestamp_safe_sub a b =
  if Int64.sub a Constants.min_timestamp >= b then Int64.sub a b
  else Constants.min_timestamp

let timestamp_safe_add a b =
  if Int64.sub Constants.max_timestamp a <= b then Int64.add a b
  else Constants.max_timestamp

let do_chunk ~drop_partial (n : int64) (s : Time.Interval.t Seq.t) :
  Time.Interval.t Seq.t =
  let rec aux n s =
    match s () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons ((x, y), rest) ->
      let size = Int64.sub y x in
      if size >= n then fun () ->
        Seq.Cons
          ( (x, Int64.add n x),
            aux n (fun () -> Seq.Cons ((Int64.add n x, y), rest)) )
      else if drop_partial then aux n rest
      else fun () -> Seq.Cons ((x, y), aux n rest)
  in
  aux n s

let intervals_of_timestamps (s : Time_ast.timestamp Seq.t) :
  Time.Interval.t Seq.t =
  let rec aux acc s =
    match s () with
    | Seq.Nil -> ( match acc with None -> Seq.empty | Some x -> Seq.return x)
    | Seq.Cons (x, rest) -> (
        match acc with
        | None -> aux (Some (x, Int64.succ x)) rest
        | Some (x', y') ->
          if y' = x then aux (Some (x', Int64.succ x)) rest
          else fun () -> Seq.Cons ((x', y'), aux None s))
  in
  aux None s

let timestamps_of_intervals (s : Time.Interval.t Seq.t) :
  Time_ast.timestamp Seq.t =
  s |> Seq.flat_map (fun (a, b) -> Seq_utils.a_to_b_exc_int64 ~a ~b)

let normalize (s : Time.Interval.t Seq.t) : Time.Interval.t Seq.t =
  s
  |> timestamps_of_intervals
  |> Int64_set.of_seq
  |> Int64_set.to_seq
  |> intervals_of_timestamps

let find_follow bound ((start, _end_exc) : Time.Interval.t)
    (s2 : Time.Interval.t Seq.t) =
  let s =
    s2
    |> OSeq.drop_while (fun (start', _) -> start' < start)
    |> OSeq.take_while (fun (start', _) -> Int64.sub start' start <= bound)
  in
  match s () with Seq.Nil -> None | Seq.Cons (x, _) -> Some x

let do_chunk_at_year_boundary tz (s : Time.Interval.t Seq.t) =
  let open Time in
  let rec aux s =
    match s () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons ((t1, t2), rest) ->
      let dt1 =
        CCResult.get_exn @@ Date_time'.of_timestamp ~tz_of_date_time:tz t1
      in
      let dt2 =
        t2
        |> Int64.pred
        |> Date_time'.of_timestamp ~tz_of_date_time:tz
        |> CCResult.get_exn
      in
      if dt1.year = dt2.year && dt1.month = dt2.month then fun () ->
        Seq.Cons ((t1, t2), aux rest)
      else
        let t' =
          Date_time'.set_to_last_day_hour_min_sec dt1
          |> Date_time'.to_timestamp
          |> Date_time'.max_of_timestamp_local_result
          |> CCOpt.get_exn
          |> Int64.succ
        in
        fun () ->
          Seq.Cons ((t1, t'), aux (fun () -> Seq.Cons ((t', t2), rest)))
  in
  aux s

let do_chunk_at_month_boundary tz (s : Time.Interval.t Seq.t) =
  let open Time in
  let rec aux s =
    match s () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons ((t1, t2), rest) ->
      let dt1 =
        CCResult.get_exn @@ Date_time'.of_timestamp ~tz_of_date_time:tz t1
      in
      let dt2 =
        t2
        |> Int64.pred
        |> Date_time'.of_timestamp ~tz_of_date_time:tz
        |> CCResult.get_exn
      in
      if dt1.year = dt2.year && dt1.month = dt2.month then fun () ->
        Seq.Cons ((t1, t2), aux rest)
      else
        let t' =
          Date_time'.set_to_last_day_hour_min_sec dt1
          |> Date_time'.to_timestamp
          |> Date_time'.max_of_timestamp_local_result
          |> CCOpt.get_exn
          |> Int64.succ
        in
        fun () ->
          Seq.Cons ((t1, t'), aux (fun () -> Seq.Cons ((t', t2), rest)))
  in
  aux s

let rec resolve ?(search_using_tz = Time_zone.utc)
    ~(search_start : Time_ast.timestamp) ~(search_end_exc : Time_ast.timestamp)
    (t : Time_ast.t) : Time.Interval.t Seq.t =
  let default_search_space = Time.(min_timestamp, max_timestamp) in
  let filter s =
    Seq.filter_map
      (fun (x, y) ->
         if y <= search_start then None
         else if search_end_exc < x then None
         else Some (max search_start x, min search_end_exc y))
      s
  in
  let rec aux (search_space : Time.Interval.t) (search_using_tz : Time_zone.t) t
    =
    let open Time_ast in
    match t with
    | Round_robin_pick_list l ->
      l
      |> List.map (fun t -> aux search_space search_using_tz t)
      |> Time.Intervals.Round_robin
         .merge_multi_list_round_robin_non_decreasing ~skip_check:true
    | Unary_op (op, t) -> (
        match op with
        | Not ->
          Seq_utils.a_to_b_exc_int64 ~a:Time.min_timestamp
            ~b:Time.max_timestamp
          |> Seq.filter (fun x -> not (mem search_space ~search_using_tz t x))
          |> intervals_of_timestamps
        | Drop_points n ->
          aux default_search_space search_using_tz t
          |> timestamps_of_intervals
          |> OSeq.drop n
          |> intervals_of_timestamps
        | Take_points n ->
          aux default_search_space search_using_tz t
          |> timestamps_of_intervals
          |> OSeq.take n
          |> intervals_of_timestamps
        | Shift n ->
          let x, y = search_space in
          aux
            (timestamp_safe_sub x n, timestamp_safe_sub y n)
            search_using_tz t
          |> Seq.map (fun (x, y) ->
              (timestamp_safe_add n x, timestamp_safe_add n y))
        | Lengthen n ->
          let x, y = search_space in
          aux (x, Int64.add y n) search_using_tz t
          |> Seq.map (fun (x, y) -> (x, timestamp_safe_add n y))
        | With_tz tz -> aux search_space tz t)
    | Follow (b, t1, t2) ->
      let x, y = search_space in
      let search_space = (timestamp_safe_sub x b, y) in
      let s1 = aux search_space search_using_tz t1 in
      let s2 = aux search_space search_using_tz t2 in
      s1 |> Seq.filter_map (fun x -> find_follow b x s2)
    | Interval_inc (b, t1, t2) ->
      let x, y = search_space in
      let search_space = (timestamp_safe_sub x b, y) in
      let s1 = aux search_space search_using_tz t1 in
      let s2 = aux search_space search_using_tz t2 in
      s1
      |> Seq.filter_map (fun (start, end_exc) ->
          find_follow b (start, end_exc) s2
          |> CCOpt.map (fun (_, end_exc') -> (start, end_exc')))
    | Interval_exc (b, t1, t2) ->
      let x, y = search_space in
      let search_space = (timestamp_safe_sub x b, y) in
      let s1 = aux search_space search_using_tz t1 in
      let s2 = aux search_space search_using_tz t2 in
      s1
      |> Seq.filter_map (fun (start, end_exc) ->
          find_follow b (start, end_exc) s2
          |> CCOpt.map (fun (start', _) -> (start, start')))
    | Unchunk chunked -> aux_chunked search_using_tz chunked |> normalize
    | _ ->
      Seq_utils.a_to_b_exc_int64 ~a:(fst search_space) ~b:(snd search_space)
      |> Seq.filter (mem ~search_using_tz search_space t)
      |> intervals_of_timestamps
  and aux_chunked search_using_tz chunked =
    let chunk_based_on_op_on_t op s =
      match op with
      | Time_ast.Chunk_disjoint_interval -> normalize s
      | Chunk_by_duration { chunk_size; drop_partial } ->
        do_chunk ~drop_partial chunk_size s
      | Chunk_at_year_boundary -> do_chunk_at_year_boundary search_using_tz s
      | Chunk_at_month_boundary -> do_chunk_at_month_boundary search_using_tz s
    in
    match chunked with
    | Unary_op_on_t (op, t) ->
      aux default_search_space search_using_tz t |> chunk_based_on_op_on_t op
    | Unary_op_on_chunked (op, c) -> (
        let s = aux_chunked search_using_tz c in
        match op with
        | Nth n -> s |> OSeq.drop n |> OSeq.take 1
        | Drop n -> OSeq.drop n s
        | Take n -> OSeq.take n s
        | Take_nth n -> OSeq.take_nth n s
        | Chunk_again op -> chunk_based_on_op_on_t op s)
  in
  aux (search_start, search_end_exc) search_using_tz t |> filter |> normalize

and mem ?(search_using_tz = Time_zone.utc)
    ((search_start, search_end_exc) : Time.Interval.t) (t : Time_ast.t)
    (timestamp : Time_ast.timestamp) : bool =
  let open Time_ast in
  let rec aux t timestamp =
    match
      Time.Date_time'.of_timestamp ~tz_of_date_time:search_using_tz timestamp
    with
    | Error () -> failwith (Printf.sprintf "Invalid timestamp: %Ld" timestamp)
    | Ok dt -> (
        let weekday =
          CCResult.get_exn
          @@ weekday_of_month_day ~year:dt.year ~month:dt.month ~mday:dt.day
        in
        match t with
        | All -> true
        | Empty -> false
        | Pattern pattern ->
          let year_is_fine =
            Int_set.is_empty pattern.years
            || Int_set.mem dt.year pattern.years
          in
          let month_is_fine =
            Month_set.is_empty pattern.months
            || Month_set.mem dt.month pattern.months
          in
          let mday_is_fine =
            Int_set.is_empty pattern.month_days
            ||
            let day_count =
              day_count_of_month ~year:dt.year ~month:dt.month
            in
            pattern.month_days
            |> Int_set.to_seq
            |> Seq.map (fun mday ->
                if mday < 0 then day_count + mday + 1 else mday)
            |> OSeq.mem ~eq:( = ) dt.day
          in
          let wday_is_fine =
            Weekday_set.is_empty pattern.weekdays
            || Weekday_set.mem weekday pattern.weekdays
          in
          let hour_is_fine =
            Int_set.is_empty pattern.hours
            || Int_set.mem dt.hour pattern.hours
          in
          let minute_is_fine =
            Int_set.is_empty pattern.minutes
            || Int_set.mem dt.minute pattern.minutes
          in
          let second_is_fine =
            Int_set.is_empty pattern.seconds
            || Int_set.mem dt.second pattern.seconds
          in
          year_is_fine
          && month_is_fine
          && mday_is_fine
          && wday_is_fine
          && hour_is_fine
          && minute_is_fine
          && second_is_fine
        | Point p -> timestamp = p
        | Unary_op (_, _)
        | Round_robin_pick_list _
        | Follow (_, _, _)
        | Interval_inc (_, _, _)
        | Interval_exc (_, _, _)
        | Unchunk _ ->
          resolve ~search_using_tz ~search_start ~search_end_exc t
          |> OSeq.exists (fun (x, y) -> x <= timestamp && timestamp < y)
        | Inter_seq s -> OSeq.for_all (fun t -> aux t timestamp) s
        | Union_seq s -> OSeq.exists (fun t -> aux t timestamp) s)
  in
  aux t timestamp
