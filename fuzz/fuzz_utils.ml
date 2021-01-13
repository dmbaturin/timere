open Date_components

let time =
  Crowbar.map
    [ Crowbar.range 2; Crowbar.range 4; Crowbar.list (Crowbar.range 1000) ]
    (fun max_height max_branching randomness ->
       let max_height = 1 + max_height in
       let max_branching = 1 + max_branching in
       Builder.build ~enable_extra_restrictions:false ~min_year:2000
         ~max_year_inc:2002 ~max_height ~max_branching ~randomness)

let time_tagged =
  Crowbar.map
    [ time ]
    (fun time ->
       time
       |> Resolver.t_of_ast
       |> Resolver.optimize_search_space Time_zone.utc
  )

let pattern =
  Crowbar.map
    [ Crowbar.list (Crowbar.range 5000) ]
    (fun randomness ->
       let min_year = 0000 in
       let max_year_inc = 9999 in
       let rng = Builder.make_rng ~randomness in
       let years =
         if rng () mod 2 = 0 then Int_set.empty
         else
           let end_inc = min 5 (rng ()) in
           OSeq.(0 -- end_inc)
           |> Seq.map (fun _ -> min max_year_inc (min_year + rng ()))
           |> Int_set.of_seq
       in
       let months =
         if rng () mod 2 = 0 then Month_set.empty
         else
           let end_inc = min 5 (rng ()) in
           OSeq.(0 -- end_inc)
           |> Seq.map (fun _ ->
               CCResult.get_exn @@ month_of_tm_int (rng () mod 12))
           |> Month_set.of_seq
       in
       let month_days =
         if rng () mod 2 = 0 then Int_set.empty
         else
           let end_inc = min 5 (rng ()) in
           OSeq.(0 -- end_inc)
           |> Seq.map (fun _ ->
               if rng () mod 2 = 0 then 1 + (rng () mod 31)
               else -(1 + (rng () mod 31)))
           |> Int_set.of_seq
       in
       let weekdays =
         if rng () mod 2 = 0 then Weekday_set.empty
         else
           let end_inc = min 5 (rng ()) in
           OSeq.(0 -- end_inc)
           |> Seq.map (fun _ ->
               CCResult.get_exn @@ weekday_of_tm_int (rng () mod 7))
           |> Weekday_set.of_seq
       in
       let hours =
         if rng () mod 2 = 0 then Int_set.empty
         else
           let end_inc = min 5 (rng ()) in
           OSeq.(0 -- end_inc)
           |> Seq.map (fun _ -> rng () mod 24)
           |> Int_set.of_seq
       in
       let minutes =
         if rng () mod 2 = 0 then Int_set.empty
         else
           let end_inc = min 5 (rng ()) in
           OSeq.(0 -- end_inc)
           |> Seq.map (fun _ -> rng () mod 60)
           |> Int_set.of_seq
       in
       let seconds =
         if rng () mod 2 = 0 then Int_set.empty
         else
           let end_inc = min 5 (rng ()) in
           OSeq.(0 -- end_inc)
           |> Seq.map (fun _ -> rng () mod 60)
           |> Int_set.of_seq
       in
       Pattern.
         { years; months; month_days; weekdays; hours; minutes; seconds })

let search_space =
  Crowbar.map
    [
      Crowbar.list
        (Crowbar.map [ Crowbar.int64; Crowbar.int64 ]
           (fun search_start search_size ->
              let search_start =
                min (max Time.min_timestamp search_start) Time.max_timestamp
              in
              let search_size = Int64.abs search_size in
              let search_end_exc =
                min Time.max_timestamp (Int64.add search_start search_size)
              in
              (search_start, search_end_exc)));
    ]
    (fun l -> CCList.to_seq l |> Time.Intervals.normalize |> CCList.of_seq)
