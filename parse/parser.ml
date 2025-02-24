open MParser
open Parser_components
module Int_map = Map.Make (CCInt)

type text_map = string Int_map.t

exception Invalid_data of string

let prefix_string_match (choices : (string * 'a) list) (s : string) :
  (string * 'a) list =
  let regexp = Re.Str.regexp_case_fold s in
  choices
  |> List.filter (fun (k, _) ->
      try Re.Str.search_forward regexp k 0 = 0 with Not_found -> false)

let invalid_data s = raise (Invalid_data s)

let text_map_union m_x m_y = Int_map.union (fun _ x _y -> Some x) m_x m_y

let text_map_empty : text_map = Int_map.empty

type guess =
  | Dot
  | Comma
  | Hyphen
  | Slash
  | Colon
  | Star
  | Not
  | Outside
  | For
  | Of
  | In
  | To
  | From
  | Am
  | Pm
  | St
  | Nd
  | Rd
  | Th
  | Days
  | Hours
  | Minutes
  | Seconds
  | Nat of int
  | Nats of int Timere.range list
  | Float of float
  | Hms of Timere.hms
  | Hmss of Timere.hms Timere.range list
  | Weekday of Timere.weekday
  | Weekdays of Timere.weekday Timere.range list
  | Month_day of int
  | Month_days of int Timere.range list
  | Month of Timere.month
  | Months of Timere.month Timere.range list
  | Ymd of
      (MParser.pos * int) * (MParser.pos * Timere.month) * (MParser.pos * int)
  | Duration of Timere.Duration.t
  | Time_zone of Timere.Time_zone.t

type token = (int * int * int) * text_map * guess

type unary_op = With_time_zone of Timere.Time_zone.t

type binary_op =
  | Union
  | Inter

type ast =
  | Tokens of token list
  | Unary_op of unary_op * ast
  | Binary_op of binary_op * ast * ast
  | Round_robin_pick of ast list

let string_of_token (_, _, guess) =
  match guess with
  | Dot -> "DOT"
  | Comma -> "COMMA"
  | Hyphen -> "HYPHEN"
  | Slash -> "SLASH"
  | Colon -> "COLON"
  | Star -> "STAR"
  | Not -> "NOT"
  | Outside -> "outside"
  | For -> "for"
  | Of -> "of"
  | In -> "in"
  | To -> "to"
  | From -> "from"
  | Am -> "am"
  | Pm -> "pm"
  | St -> "st"
  | Nd -> "nd"
  | Rd -> "rd"
  | Th -> "th"
  | Days -> "days"
  | Hours -> "hours"
  | Minutes -> "minutes"
  | Seconds -> "seconds"
  | Nat n -> string_of_int n
  | Nats _ -> "nats"
  | Float n -> string_of_float n
  | Hms _ -> "hms"
  | Hmss _ -> "hmss"
  | Weekday _ -> "weekday"
  | Weekdays _ -> "weekdays"
  | Month_day _ -> "month_day"
  | Month_days _ -> "month_days"
  | Month _ -> "month"
  | Months _ -> "months"
  | Ymd _ -> "ymd"
  | Duration _ -> "duration"
  | Time_zone tz -> Timere.Time_zone.name tz

let weekdays : (string * Timere.weekday) list =
  [
    ("sunday", `Sun);
    ("monday", `Mon);
    ("tuesday", `Tue);
    ("wednesday", `Wed);
    ("thursday", `Thu);
    ("friday", `Fri);
    ("saturday", `Sat);
  ]

let months : (string * Timere.month) list =
  [
    ("january", `Jan);
    ("february", `Feb);
    ("march", `Mar);
    ("april", `Apr);
    ("may", `May);
    ("june", `Jun);
    ("july", `Jul);
    ("august", `Aug);
    ("september", `Sep);
    ("october", `Oct);
    ("november", `Nov);
    ("december", `Dec);
  ]

let parse_weekday (s : string) : (Timere.weekday, unit) CCResult.t =
  match prefix_string_match weekdays s with [ (_, x) ] -> Ok x | _ -> Error ()

let parse_month (s : string) : (Timere.month, unit) CCResult.t =
  match prefix_string_match months s with [ (_, x) ] -> Ok x | _ -> Error ()

let weekday_p : (Timere.weekday, unit) t =
  alpha_string
  >>= fun x ->
  if String.length x < 3 then fail (Printf.sprintf "String too short")
  else
    match parse_weekday x with
    | Ok x -> return x
    | Error _ -> fail (Printf.sprintf "Failed to interpret weekday string")

let month_p : (Timere.month, unit) t =
  alpha_string
  >>= fun x ->
  if String.length x < 3 then fail (Printf.sprintf "String too short")
  else
    match parse_month x with
    | Ok x -> return x
    | Error _ -> fail (Printf.sprintf "Failed to interpret month string: %s" x)

let symbols = "()[]&|>"

module String_map = CCMap.Make (String)

let time_zones =
  Timere.Time_zone.available_time_zones
  |> List.map (fun x -> (String.lowercase_ascii x, x))
  |> String_map.of_list

let token_p : (token, unit) MParser.t =
  get_pos
  >>= fun pos ->
  choice
    [
      attempt (char '.') >>$ (Int_map.empty, Dot);
      attempt (char ',') >>$ (Int_map.empty, Comma);
      attempt (char '-') >>$ (Int_map.empty, Hyphen);
      attempt (char '/') >>$ (Int_map.empty, Slash);
      attempt (char ':') >>$ (Int_map.empty, Colon);
      attempt (char '*') >>$ (Int_map.empty, Star);
      (* (attempt float_non_neg |>> fun x -> Float x); *)
      (attempt nat_zero_w_original_str
       |>> fun (x, s) ->
       let i, _, _ = pos in
       (Int_map.add i s Int_map.empty, Nat x));
      (attempt weekday_p |>> fun x -> (Int_map.empty, Weekday x));
      (attempt month_p |>> fun x -> (Int_map.empty, Month x));
      attempt (string "not") >>$ (Int_map.empty, Not);
      attempt (string "outside") >>$ (Int_map.empty, Outside);
      attempt (string "for") >>$ (Int_map.empty, For);
      attempt (string "of") >>$ (Int_map.empty, Of);
      attempt (string "in") >>$ (Int_map.empty, In);
      attempt (string "to") >>$ (Int_map.empty, To);
      attempt (string "from") >>$ (Int_map.empty, From);
      attempt (string "am") >>$ (Int_map.empty, Am);
      attempt (string "AM") >>$ (Int_map.empty, Am);
      attempt (string "pm") >>$ (Int_map.empty, Pm);
      attempt (string "PM") >>$ (Int_map.empty, Pm);
      attempt (string "st") >>$ (Int_map.empty, St);
      attempt (string "nd") >>$ (Int_map.empty, Nd);
      attempt (string "rd") >>$ (Int_map.empty, Rd);
      attempt (string "th") >>$ (Int_map.empty, Th);
      attempt (string "days") >>$ (Int_map.empty, Days);
      attempt (string "day") >>$ (Int_map.empty, Days);
      attempt (string "d") >>$ (Int_map.empty, Days);
      attempt (string "hours") >>$ (Int_map.empty, Hours);
      attempt (string "hour") >>$ (Int_map.empty, Hours);
      attempt (string "h") >>$ (Int_map.empty, Hours);
      attempt (string "minutes") >>$ (Int_map.empty, Minutes);
      attempt (string "minute") >>$ (Int_map.empty, Minutes);
      attempt (string "mins") >>$ (Int_map.empty, Minutes);
      attempt (string "min") >>$ (Int_map.empty, Minutes);
      attempt (string "m") >>$ (Int_map.empty, Minutes);
      attempt (string "seconds") >>$ (Int_map.empty, Seconds);
      attempt (string "second") >>$ (Int_map.empty, Seconds);
      attempt (string "secs") >>$ (Int_map.empty, Seconds);
      attempt (string "sec") >>$ (Int_map.empty, Seconds);
      attempt (string "s") >>$ (Int_map.empty, Seconds);
      attempt
        (many1_satisfy (fun c -> c <> ' ' && not (String.contains symbols c))
         >>= fun s ->
         match String_map.find_opt (String.lowercase_ascii s) time_zones with
         | None -> fail ""
         | Some s -> (
             match Timere.Time_zone.make s with
             | None -> fail ""
             | Some tz -> return (Int_map.empty, Time_zone tz)));
      (attempt
         (many1_satisfy (fun c -> c <> ' ' && not (String.contains symbols c)))
       >>= fun s ->
       fail (Printf.sprintf "%s: Unrecognized token: %s" (string_of_pos pos) s));
    ]
  >>= fun (guess, original_str) -> spaces >> return (pos, guess, original_str)

let tokens_p = spaces >> many1 token_p << spaces

let inter : (ast -> ast -> ast, unit) t =
  spaces >> string "&&" >> spaces >> return (fun a b -> Binary_op (Inter, a, b))

let union : (ast -> ast -> ast, unit) t =
  spaces >> string "||" >> spaces >> return (fun a b -> Binary_op (Union, a, b))

(* let round_robin_pick : (ast -> ast -> ast, unit) t =
 *   spaces >> string ">>" >> return (fun a b -> Round_robin_pick [ a; b ]) *)

let expr =
  let rec expr mparser_state =
    let inter_part =
      attempt (char '(')
      >> (spaces >> expr << spaces << char ')')
         <|> (tokens_p |>> fun l -> Tokens l)
    in
    (* let ordered_select_part = chain_left1 inter_part round_robin_pick in *)
    let union_part = chain_left1 inter_part inter in
    chain_left1 union_part union mparser_state
  in
  expr

module Ast_normalize = struct
  let group (type a) ~(extract_single : guess -> a option)
      ~(extract_grouped : guess -> a Timere.range list option)
      ~(constr_grouped : a Timere.range list -> guess) (l : token list) :
    token list =
    let rec recognize_single_interval tokens : token list =
      match tokens with
      | [ (pos_x, m, x) ] -> (
          match extract_single x with
          | Some x ->
            (pos_x, m, constr_grouped [ `Range_inc (x, x) ])
            :: recognize_single_interval []
          | _ -> recognize_fallback tokens)
      | (pos_x, m, x) :: (pos_comma, _, Comma) :: rest -> (
          match extract_single x with
          | Some x ->
            (pos_x, m, constr_grouped [ `Range_inc (x, x) ])
            :: recognize_single_interval
              ((pos_comma, text_map_empty, Comma) :: rest)
          | _ -> recognize_fallback tokens)
      | (pos_x, m_x, x)
        :: (_, _, To) :: (_, m_y, y) :: (pos_comma, _, Comma) :: rest -> (
          match (extract_single x, extract_single y) with
          | Some x, Some y ->
            ( pos_x,
              text_map_union m_x m_y,
              constr_grouped [ `Range_inc (x, y) ] )
            :: recognize_single_interval
              ((pos_comma, text_map_empty, Comma) :: rest)
          | _, _ -> recognize_fallback tokens)
      | (pos_comma, _, Comma)
        :: (pos_x, m_x, x) :: (_, _, To) :: (_, m_y, y) :: rest -> (
          match (extract_single x, extract_single y) with
          | Some x, Some y ->
            (pos_comma, text_map_empty, Comma)
            :: ( pos_x,
                 text_map_union m_x m_y,
                 constr_grouped [ `Range_inc (x, y) ] )
            :: recognize_single_interval rest
          | _, _ -> recognize_fallback tokens)
      | _ -> recognize_fallback tokens
    and recognize_fallback l =
      match l with
      | [] -> []
      | token :: rest -> token :: recognize_single_interval rest
    in
    let rec merge_intervals tokens : token list =
      match tokens with
      | (pos_x, m_x, x) :: (_, _, Comma) :: (_, m_y, y) :: rest -> (
          match (extract_grouped x, extract_grouped y) with
          | Some l1, Some l2 ->
            merge_intervals
              ((pos_x, text_map_union m_x m_y, constr_grouped (l1 @ l2))
               :: rest)
          | _, _ -> merge_fallback tokens)
      | _ -> merge_fallback tokens
    and merge_fallback l =
      match l with [] -> [] | token :: rest -> token :: merge_intervals rest
    in
    l |> recognize_single_interval |> merge_intervals

  let ungroup (type a) ~(extract_grouped : guess -> a Timere.range list option)
      ~(constr_single : a -> guess) (l : token list) : token list =
    let rec aux tokens =
      match tokens with
      | [] -> []
      | (pos_x, m_x, x) :: rest -> (
          match extract_grouped x with
          | Some [ `Range_inc (x1, x2) ] when x1 = x2 ->
            (pos_x, m_x, constr_single x1) :: aux rest
          | _ -> (pos_x, m_x, x) :: aux rest)
    in
    aux l

  let group_nats (l : token list) : token list =
    group
      ~extract_single:(function Nat x -> Some x | _ -> None)
      ~extract_grouped:(function Nats l -> Some l | _ -> None)
      ~constr_grouped:(fun l -> Nats l)
      l

  let ungroup_nats l =
    ungroup
      ~extract_grouped:(function Nats l -> Some l | _ -> None)
      ~constr_single:(fun x -> Nat x)
      l

  let group_months (l : token list) : token list =
    group
      ~extract_single:(function Month x -> Some x | _ -> None)
      ~extract_grouped:(function Months l -> Some l | _ -> None)
      ~constr_grouped:(fun x -> Months x)
      l

  let ungroup_months l =
    ungroup
      ~extract_grouped:(function Months l -> Some l | _ -> None)
      ~constr_single:(fun x -> Month x)
      l

  let group_weekdays (l : token list) : token list =
    group
      ~extract_single:(function Weekday x -> Some x | _ -> None)
      ~extract_grouped:(function Weekdays l -> Some l | _ -> None)
      ~constr_grouped:(fun x -> Weekdays x)
      l

  let ungroup_weekdays l =
    ungroup
      ~extract_grouped:(function Weekdays l -> Some l | _ -> None)
      ~constr_single:(fun x -> Weekday x)
      l

  let recognize_month_day (l : token list) : token list =
    let rec recognize_single tokens =
      match tokens with
      | (pos_x, _, Nat x) :: (_, _, St) :: rest
      | (pos_x, _, Nat x) :: (_, _, Nd) :: rest
      | (pos_x, _, Nat x) :: (_, _, Rd) :: rest
      | (pos_x, _, Nat x) :: (_, _, Th) :: rest ->
        (pos_x, text_map_empty, Month_day x) :: recognize_single rest
      | [] -> []
      | x :: xs -> x :: recognize_single xs
    in
    let rec propagate_guesses tokens =
      match tokens with
      | (pos_x, _, Month_day x)
        :: (pos_comma, _, Comma) :: (pos_y, _, Nat y) :: rest ->
        (pos_x, text_map_empty, Month_day x)
        :: (pos_comma, text_map_empty, Comma)
        :: propagate_guesses ((pos_y, text_map_empty, Month_day y) :: rest)
      | (pos_x, _, Month_day x) :: (pos_to, _, To) :: (pos_y, _, Nat y) :: rest
        ->
        (pos_x, text_map_empty, Month_day x)
        :: (pos_to, text_map_empty, To)
        :: propagate_guesses ((pos_y, text_map_empty, Month_day y) :: rest)
      | [] -> []
      | x :: xs -> x :: propagate_guesses xs
    in
    l
    |> recognize_single
    |> propagate_guesses
    |> List.rev
    |> propagate_guesses
    |> List.rev

  let group_month_days (l : token list) : token list =
    group
      ~extract_single:(function Month_day x -> Some x | _ -> None)
      ~extract_grouped:(function Month_days l -> Some l | _ -> None)
      ~constr_grouped:(fun x -> Month_days x)
      l

  let ungroup_month_days l =
    ungroup
      ~extract_grouped:(function Month_days l -> Some l | _ -> None)
      ~constr_single:(fun x -> Month_day x)
      l

  type hms_mode =
    | Hms_24
    | Hms_am
    | Hms_pm

  let recognize_hms (l : token list) : token list =
    let make_hms mode ~pos_hour ~hour ?pos_minute ?(minute = 0) ?pos_second
        ?(second = 0) () : token =
      let hour =
        match mode with
        | Hms_24 ->
          if 0 <= hour && hour < 24 then hour
          else
            invalid_data
              (Printf.sprintf "%s: Invalid hour: %d" (string_of_pos pos_hour)
                 hour)
        | Hms_am ->
          if 1 <= hour && hour <= 12 then hour mod 12
          else
            invalid_data
              (Printf.sprintf "%s: Invalid hour: %d am"
                 (string_of_pos pos_hour) hour)
        | Hms_pm ->
          if 1 <= hour && hour <= 12 then (hour mod 12) + 12
          else
            invalid_data
              (Printf.sprintf "%s: Invalid hour: %d pm"
                 (string_of_pos pos_hour) hour)
      in
      if 0 <= minute && minute < 60 then
        if 0 <= second && second < 60 then
          ( pos_hour,
            text_map_empty,
            Hms (Timere.make_hms_exn ~hour ~minute ~second) )
        else
          invalid_data
            (Printf.sprintf "%s: Invalid second: %d"
               (string_of_pos @@ CCOpt.get_exn @@ pos_second)
               minute)
      else
        invalid_data
          (Printf.sprintf "%s: Invalid minute: %d"
             (string_of_pos @@ CCOpt.get_exn @@ pos_minute)
             minute)
    in
    let rec aux acc (l : token list) : token list =
      match l with
      | (pos_hour, _, Nat hour)
        :: (_, _, Colon)
        :: (pos_minute, _, Nat minute)
        :: (_, _, Colon)
        :: (pos_second, _, Nat second) :: (_, _, Am) :: rest ->
        let token =
          make_hms Hms_am ~pos_hour ~hour ~pos_minute ~minute ~pos_second
            ~second ()
        in
        aux (token :: acc) rest
      | (pos_hour, _, Nat hour)
        :: (_, _, Colon)
        :: (pos_minute, _, Nat minute)
        :: (_, _, Colon)
        :: (pos_second, _, Nat second) :: (_, _, Pm) :: rest ->
        let token =
          make_hms Hms_pm ~pos_hour ~hour ~pos_minute ~minute ~pos_second
            ~second ()
        in
        aux (token :: acc) rest
      | (pos_hour, _, Nat hour)
        :: (_, _, Colon)
        :: (pos_minute, _, Nat minute)
        :: (_, _, Colon) :: (pos_second, _, Nat second) :: rest ->
        let token =
          make_hms Hms_24 ~pos_hour ~hour ~pos_minute ~minute ~pos_second
            ~second ()
        in
        aux (token :: acc) rest
      | (pos_hour, _, Nat hour)
        :: (_, _, Colon) :: (pos_minute, _, Nat minute) :: (_, _, Am) :: rest ->
        let token = make_hms Hms_am ~pos_hour ~hour ~pos_minute ~minute () in
        aux (token :: acc) rest
      | (pos_hour, _, Nat hour)
        :: (_, _, Colon) :: (pos_minute, _, Nat minute) :: (_, _, Pm) :: rest ->
        let token = make_hms Hms_pm ~pos_hour ~hour ~pos_minute ~minute () in
        aux (token :: acc) rest
      | (pos_hour, _, Nat hour)
        :: (_, _, Colon) :: (pos_minute, _, Nat minute) :: rest ->
        let token = make_hms Hms_24 ~pos_hour ~hour ~pos_minute ~minute () in
        aux (token :: acc) rest
      | (pos_hour, _, Nat hour) :: (_, _, Am) :: rest ->
        let token = make_hms Hms_am ~pos_hour ~hour () in
        aux (token :: acc) rest
      | (pos_hour, _, Nat hour) :: (_, _, Pm) :: rest ->
        let token = make_hms Hms_pm ~pos_hour ~hour () in
        aux (token :: acc) rest
      | [] -> List.rev acc
      | token :: rest -> aux (token :: acc) rest
    in
    aux [] l

  let group_hms (l : token list) : token list =
    group
      ~extract_single:(function Hms x -> Some x | _ -> None)
      ~extract_grouped:(function Hmss l -> Some l | _ -> None)
      ~constr_grouped:(fun x -> Hmss x)
      l

  let ungroup_hms l =
    ungroup
      ~extract_grouped:(function Hmss l -> Some l | _ -> None)
      ~constr_single:(fun x -> Hms x)
      l

  let recognize_duration (l : token list) : token list =
    let make_duration ~pos ~days ~hours ~minutes ~seconds =
      ( CCOpt.get_exn pos,
        text_map_empty,
        Duration
          (Timere.Duration.make_frac
             ~days:(CCOpt.value ~default:0.0 days)
             ~hours:(CCOpt.value ~default:0.0 hours)
             ~minutes:(CCOpt.value ~default:0.0 minutes)
             ~seconds ()) )
    in
    let rec aux_start_with_days acc l =
      match l with
      | (pos, _, Nat days) :: (_, _, Days) :: rest ->
        aux_start_with_hours ~pos:(Some pos)
          ~days:(Some (float_of_int days))
          acc rest
      | (pos, _, Float days) :: (_, _, Days) :: rest ->
        aux_start_with_hours ~pos:(Some pos) ~days:(Some days) acc rest
      | _ -> aux_start_with_hours ~pos:None ~days:None acc l
    and aux_start_with_hours ~pos ~days acc l =
      match l with
      | (pos_hours, _, Nat hours) :: (_, _, Hours) :: rest ->
        aux_start_with_minutes
          ~pos:(Some (CCOpt.value ~default:pos_hours pos))
          ~days
          ~hours:(Some (float_of_int hours))
          acc rest
      | (pos_hours, _, Float hours) :: (_, _, Hours) :: rest ->
        aux_start_with_minutes
          ~pos:(Some (CCOpt.value ~default:pos_hours pos))
          ~days ~hours:(Some hours) acc rest
      | _ -> aux_start_with_minutes ~pos ~days ~hours:None acc l
    and aux_start_with_minutes ~pos ~days ~hours acc l =
      match l with
      | (pos_minutes, _, Nat minutes) :: (_, _, Minutes) :: rest ->
        aux_start_with_seconds
          ~pos:(Some (CCOpt.value ~default:pos_minutes pos))
          ~days ~hours
          ~minutes:(Some (float_of_int minutes))
          acc rest
      | (pos_minutes, _, Float minutes) :: (_, _, Minutes) :: rest ->
        aux_start_with_seconds
          ~pos:(Some (CCOpt.value ~default:pos_minutes pos))
          ~days ~hours ~minutes:(Some minutes) acc rest
      | _ -> aux_start_with_seconds ~pos ~days ~hours ~minutes:None acc l
    and aux_start_with_seconds ~pos ~days ~hours ~minutes acc l =
      match l with
      | (pos_seconds, _, Nat seconds) :: (_, _, Seconds) :: rest ->
        let token =
          ( CCOpt.value ~default:pos_seconds pos,
            text_map_empty,
            Duration
              (Timere.Duration.make_frac
                 ~days:(CCOpt.value ~default:0.0 days)
                 ~hours:(CCOpt.value ~default:0.0 hours)
                 ~minutes:(CCOpt.value ~default:0.0 minutes)
                 ~seconds:(float_of_int seconds) ()) )
        in
        aux_start_with_days (token :: acc) rest
      | [] ->
        if CCOpt.is_some days || CCOpt.is_some hours || CCOpt.is_some minutes
        then
          let new_token =
            make_duration ~pos ~days ~hours ~minutes ~seconds:0.0
          in
          List.rev (new_token :: acc)
        else List.rev acc
      | token :: rest ->
        if CCOpt.is_some days || CCOpt.is_some hours || CCOpt.is_some minutes
        then
          let new_token =
            make_duration ~pos ~days ~hours ~minutes ~seconds:0.0
          in
          aux_start_with_days (token :: new_token :: acc) rest
        else aux_start_with_days (token :: acc) rest
    in
    aux_start_with_days [] l

  let recognize_ymd (l : token list) : token list =
    let rec aux l =
      match l with
      | [] -> []
      | (pos_year, _, Nat year)
        :: (pos_month, _, Month month) :: (pos_day, _, Nat day) :: rest
      | (pos_year, _, Nat year)
        :: (pos_month, _, Month month) :: (pos_day, _, Month_day day) :: rest
        when year > 31 ->
        ( pos_year,
          text_map_empty,
          Ymd ((pos_year, year), (pos_month, month), (pos_day, day)) )
        :: aux rest
      | (pos_year, _, Nat year)
        :: (pos_day, _, Nat day)
        :: (_, _, Of) :: (pos_month, _, Month month) :: rest
      | (pos_year, _, Nat year)
        :: (pos_day, _, Month_day day)
        :: (_, _, Of) :: (pos_month, _, Month month) :: rest
        when year > 31 ->
        ( pos_year,
          text_map_empty,
          Ymd ((pos_year, year), (pos_month, month), (pos_day, day)) )
        :: aux rest
      | (pos_day, _, Nat day)
        :: (pos_month, _, Month month) :: (pos_year, _, Nat year) :: rest
      | (pos_day, _, Month_day day)
        :: (pos_month, _, Month month) :: (pos_year, _, Nat year) :: rest
        when year > 31 ->
        ( pos_day,
          text_map_empty,
          Ymd ((pos_year, year), (pos_month, month), (pos_day, day)) )
        :: aux rest
      | (pos_month, _, Month month)
        :: (pos_day, _, Nat day) :: (pos_year, _, Nat year) :: rest
      | (pos_month, _, Month month)
        :: (pos_day, _, Month_day day) :: (pos_year, _, Nat year) :: rest
        when year > 31 ->
        ( pos_day,
          text_map_empty,
          Ymd ((pos_year, year), (pos_month, month), (pos_day, day)) )
        :: aux rest
      | (pos_day, _, Nat day)
        :: (_, _, Of)
        :: (pos_month, _, Month month) :: (pos_year, _, Nat year) :: rest
      | (pos_day, _, Month_day day)
        :: (_, _, Of)
        :: (pos_month, _, Month month) :: (pos_year, _, Nat year) :: rest
        when year > 31 ->
        ( pos_day,
          text_map_empty,
          Ymd ((pos_year, year), (pos_month, month), (pos_day, day)) )
        :: aux rest
      | (pos_year, _, Nat year)
        :: (_, _, Hyphen)
        :: (pos_month, _, Nat month)
        :: (_, _, Hyphen) :: (pos_day, _, Nat day) :: rest
      | (pos_year, _, Nat year)
        :: (_, _, Slash)
        :: (pos_month, _, Nat month)
        :: (_, _, Slash) :: (pos_day, _, Nat day) :: rest
      | (pos_year, _, Nat year)
        :: (_, _, Dot)
        :: (pos_month, _, Nat month)
        :: (_, _, Dot) :: (pos_day, _, Nat day) :: rest
        when year > 31 -> (
          match Timere.Utils.month_of_human_int month with
          | None ->
            invalid_data
              (Printf.sprintf "%s: Invalid month" (string_of_pos pos_month))
          | Some month ->
            ( pos_year,
              text_map_empty,
              Ymd ((pos_year, year), (pos_month, month), (pos_day, day)) )
            :: aux rest)
      | (pos_day, _, Nat day)
        :: (_, _, Hyphen)
        :: (pos_month, _, Nat month)
        :: (_, _, Hyphen) :: (pos_year, _, Nat year) :: rest
      | (pos_day, _, Nat day)
        :: (_, _, Slash)
        :: (pos_month, _, Nat month)
        :: (_, _, Slash) :: (pos_year, _, Nat year) :: rest
      | (pos_day, _, Nat day)
        :: (_, _, Dot)
        :: (pos_month, _, Nat month)
        :: (_, _, Dot) :: (pos_year, _, Nat year) :: rest
        when year > 31 -> (
          match Timere.Utils.month_of_human_int month with
          | None ->
            invalid_data
              (Printf.sprintf "%s: Invalid month" (string_of_pos pos_month))
          | Some month ->
            ( pos_day,
              text_map_empty,
              Ymd ((pos_year, year), (pos_month, month), (pos_day, day)) )
            :: aux rest)
      | x :: xs -> x :: aux xs
    in
    aux l

  let recognize_float (l : token list) : token list =
    let make_float ~pos_x ~x ~pos_y ~m_y =
      let i_y, _, _ = pos_y in
      ( pos_x,
        text_map_empty,
        Float
          (float_of_string (Printf.sprintf "%d.%s" x (Int_map.find i_y m_y))) )
    in
    let flush_buffer buffer : token list =
      match List.rev buffer with
      | [ (pos_x, _, Nat x); (_, _, Dot); (pos_y, m_y, Nat _) ] ->
        [ make_float ~pos_x ~x ~pos_y ~m_y ]
      | l -> l
    in
    let rec aux buffer l =
      match l with
      | [] -> flush_buffer buffer
      | [ (pos_dot, m_dot, Dot) ] ->
        flush_buffer buffer @ [ (pos_dot, m_dot, Dot) ]
      | (pos_dot, m_dot, Dot) :: x :: rest -> (
          match buffer with
          | [] -> (pos_dot, m_dot, Dot) :: aux [] (x :: rest)
          | buffer -> aux (x :: (pos_dot, m_dot, Dot) :: buffer) rest)
      | x :: rest -> (
          match buffer with
          | [] -> aux [ x ] rest
          | buffer -> flush_buffer buffer @ aux [] (x :: rest))
    in
    aux [] l

  let process_tokens (e : ast) : (ast, string) CCResult.t =
    let rec aux e =
      match e with
      | Tokens l -> (
          let l =
            l
            |> recognize_hms
            |> recognize_float
            |> recognize_duration
            |> recognize_month_day
            |> group_nats
            |> group_month_days
            |> group_weekdays
            |> group_months
            |> group_hms
            |> ungroup_nats
            |> ungroup_month_days
            |> ungroup_weekdays
            |> ungroup_months
            |> ungroup_hms
            |> recognize_ymd
          in
          match l with
          | [] -> Tokens l
          | _ -> (
              match l with
              | (_, _, Time_zone tz) :: rest ->
                Unary_op (With_time_zone tz, Tokens rest)
              | _ -> (
                  match List.rev l with
                  | (_, _, Time_zone tz) :: rest ->
                    Unary_op (With_time_zone tz, Tokens (List.rev rest))
                  | _ -> Tokens l)))
      | Unary_op (op, e) -> Unary_op (op, aux e)
      | Binary_op (op, e1, e2) -> Binary_op (op, aux e1, aux e2)
      | Round_robin_pick l -> Round_robin_pick (List.map aux l)
    in
    try Ok (aux e) with Invalid_data msg -> Error msg

  let flatten_round_robin_select (e : ast) : ast =
    let rec aux e =
      match e with
      | Tokens _ -> e
      | Unary_op (op, e) -> Unary_op (op, aux e)
      | Binary_op (op, e1, e2) -> Binary_op (op, aux e1, aux e2)
      | Round_robin_pick l ->
        l
        |> CCList.to_seq
        |> Seq.map aux
        |> Seq.flat_map (fun e ->
            match e with
            | Round_robin_pick l -> CCList.to_seq l
            | _ -> Seq.return e)
        |> CCList.of_seq
        |> fun l -> Round_robin_pick l
    in
    aux e

  let normalize (e : ast) : (ast, string) CCResult.t =
    e |> flatten_round_robin_select |> process_tokens
end

let parse_into_ast (s : string) : (ast, string) CCResult.t =
  parse_string
    (expr
     << spaces
     >>= fun e ->
     get_pos
     >>= fun pos ->
     attempt eof
     >> return e
        <|> fail (Printf.sprintf "Expected EOI, pos: %s" (string_of_pos pos)))
    s ()
  |> result_of_mparser_result

type 'a rule_result =
  [ `Some of 'a
  | `None
  | `Error of string
  ]

let map_rule_result (f : 'a -> 'b) (x : 'a rule_result) : 'b rule_result =
  match x with
  | `Some x -> `Some (f x)
  | `None -> `None
  | `Error msg -> `Error msg

let flatten_months pos (l : Timere.month Timere.range list) :
  Timere.month list rule_result =
  match Timere.Utils.flatten_month_range_list l with
  | Some x -> `Some x
  | None ->
    `Error (Printf.sprintf "%s: Invalid month ranges" (string_of_pos pos))

let flatten_weekdays pos (l : Timere.weekday Timere.range list) :
  Timere.weekday list rule_result =
  match Timere.Utils.flatten_weekday_range_list l with
  | Some x -> `Some x
  | None ->
    `Error (Printf.sprintf "%s: Invalid weekday ranges" (string_of_pos pos))

let flatten_month_days pos (l : int Timere.range list) : int list rule_result =
  match Timere.Utils.flatten_month_day_range_list l with
  | Some x -> `Some x
  | None ->
    `Error (Printf.sprintf "%s: Invalid month day ranges" (string_of_pos pos))

let pattern ?(years = []) ?(months = []) ?pos_days ?(days = []) ?(weekdays = [])
    ?(hms : Timere.hms option) () : Timere.t rule_result =
  if not (List.for_all (fun x -> 1 <= x && x <= 31) days) then
    `Error
      (Printf.sprintf "%s: Invalid month days"
         (string_of_pos @@ CCOpt.get_exn @@ pos_days))
  else
    let f = Timere.pattern ~years ~months ~days ~weekdays in
    match hms with
    | None -> `Some (f ())
    | Some hms ->
      `Some
        (f ~hours:[ hms.hour ] ~minutes:[ hms.minute ] ~seconds:[ hms.second ]
           ())

type lean_toward =
  [ `Front
  | `Back
  ]

let points ?year ?month ?pos_day ?day ?weekday ?(hms : Timere.hms option)
    (lean_toward : lean_toward) : Timere.points rule_result =
  match day with
  | Some day when not (1 <= day && day <= 31) ->
    `Error
      (Printf.sprintf "%s: Invalid month days"
         (string_of_pos @@ CCOpt.get_exn @@ pos_day))
  | _ -> (
      let default_month =
        match lean_toward with `Front -> `Jan | `Back -> `Dec
      in
      let default_day = match lean_toward with `Front -> 1 | `Back -> -1 in
      let default_hour = match lean_toward with `Front -> 0 | `Back -> 23 in
      let default_minute = match lean_toward with `Front -> 0 | `Back -> 59 in
      let default_second = match lean_toward with `Front -> 0 | `Back -> 59 in
      match (year, month, day, weekday, hms) with
      | None, None, None, None, Some hms ->
        `Some
          (Timere.make_points_exn ~hour:hms.hour ~minute:hms.minute
             ~second:hms.second ())
      | None, None, None, Some weekday, Some hms ->
        `Some
          (Timere.make_points_exn ~weekday ~hour:hms.hour ~minute:hms.minute
             ~second:hms.second ())
      | None, None, Some day, None, Some hms ->
        `Some
          (Timere.make_points_exn ~day ~hour:hms.hour ~minute:hms.minute
             ~second:hms.second ())
      | None, Some month, Some day, None, Some hms ->
        `Some
          (Timere.make_points_exn ~month ~day ~hour:hms.hour
             ~minute:hms.minute ~second:hms.second ())
      | Some year, Some month, Some day, None, Some hms ->
        `Some
          (Timere.make_points_exn ~year ~month ~day ~hour:hms.hour
             ~minute:hms.minute ~second:hms.second ())
      | Some year, None, None, None, None ->
        `Some
          (Timere.make_points_exn ~year ~month:default_month ~day:default_day
             ~hour:default_hour ~minute:default_minute ~second:default_second
             ())
      | None, Some month, None, None, None ->
        `Some
          (Timere.make_points_exn ~month ~day:default_day ~hour:default_hour
             ~minute:default_minute ~second:default_second ())
      | None, None, Some day, None, None ->
        `Some
          (Timere.make_points_exn ~day ~hour:default_hour
             ~minute:default_minute ~second:default_second ())
      | None, None, None, Some weekday, None ->
        `Some
          (Timere.make_points_exn ~weekday ~hour:default_hour
             ~minute:default_minute ~second:default_second ())
      | _ -> invalid_arg "points")

let t_of_hmss (hmss : Timere.hms Timere.range list) =
  match
    List.map
      (fun hms_range ->
         match hms_range with
         | `Range_inc (x, y) -> (
             if x = y then
               Ok
                 Timere.(
                   pattern ~hours:[ x.hour ] ~minutes:[ x.minute ]
                     ~seconds:[ x.second ] ())
             else
               match (points ~hms:x `Front, points ~hms:y `Front) with
               | `Some p1, `Some p2 ->
                 Ok
                   Timere.(
                     bounded_intervals `Whole (Duration.make ~days:2 ()) p1 p2)
               | _ -> Error ())
         | _ -> failwith "unexpected case")
      hmss
    |> Misc_utils.get_ok_error_list
  with
  | Ok l -> `Some (List.fold_left Timere.( ||| ) Timere.empty l)
  | Error _ -> `None

module Rules = struct
  let rule_star l =
    match l with [ (_, _, Star) ] -> `Some Timere.always | _ -> `None

  let rule_weekdays l =
    match l with
    | [ (_, _, Weekday x) ] -> `Some (Timere.weekdays [ x ])
    | [ (pos, _, Weekdays l) ] ->
      flatten_weekdays pos l |> map_rule_result (fun l -> Timere.weekdays l)
    | _ -> `None

  (* let rule_month_day l =
   *   match l with
   *   | [ (_, Month_day x) ] -> Ok (Timere.days [ x ])
   *   | [ (pos, Month_days l) ] ->
   *     flatten_month_days pos l |> CCResult.map (fun l -> Timere.days l)
   *   | _ -> Error None *)

  let rule_month_days l =
    match l with
    | [ (pos_days, _, Month_day day) ] -> pattern ~pos_days ~days:[ day ] ()
    | [ (pos_days, _, Month_days day_ranges) ] -> (
        match flatten_month_days pos_days day_ranges with
        | `Some days -> pattern ~pos_days ~days ()
        | `None -> `None
        | `Error msg -> `Error msg)
    | _ -> `None

  let rule_month_and_days l =
    match l with
    | [ (_, _, Month month); (pos_days, _, Month_day day) ] ->
      pattern ~months:[ month ] ~pos_days ~days:[ day ] ()
    | [ (_, _, Month month); (pos_days, _, Nat day) ] when day <= 31 ->
      pattern ~months:[ month ] ~pos_days ~days:[ day ] ()
    | [ (_, _, Month month); (pos_days, _, Month_days day_ranges) ]
    | [ (_, _, Month month); (pos_days, _, Nats day_ranges) ] -> (
        match flatten_month_days pos_days day_ranges with
        | `Some days ->
          if List.for_all (fun day -> day <= 31) days then
            pattern ~months:[ month ] ~pos_days ~days ()
          else `None
        | `None -> `None
        | `Error msg -> `Error msg)
    | _ -> `None

  let rule_month l =
    match l with
    | [ (_, _, Month x) ] -> `Some (Timere.months [ x ])
    | [ (pos, _, Months l) ] ->
      flatten_months pos l |> map_rule_result (fun l -> Timere.months l)
    | _ -> `None

  let rule_ymd l =
    match l with
    | [ (_, _, Ymd ((_, year), (_, month), (pos_days, day))) ] ->
      pattern ~years:[ year ] ~months:[ month ] ~pos_days ~days:[ day ] ()
    | _ -> `None

  let rule_ym l =
    match l with
    | [ (_, _, Nat year); (_, _, Month month) ]
    | [ (_, _, Month month); (_, _, Nat year) ]
      when year > 31 ->
      pattern ~years:[ year ] ~months:[ month ] ()
    | _ -> `None

  let rule_md l =
    match l with
    | [ (_, _, Month month); (pos_days, _, Nat day) ]
    | [ (pos_days, _, Nat day); (_, _, Month month) ]
      when day <= 31 ->
      pattern ~months:[ month ] ~pos_days ~days:[ day ] ()
    | [ (_, _, Month month); (pos_days, _, Month_day day) ]
    | [ (pos_days, _, Month_day day); (_, _, Month month) ] ->
      pattern ~months:[ month ] ~pos_days ~days:[ day ] ()
    | [ (pos_days, _, Nat day); (_, _, Of); (_, _, Month month) ] when day <= 31
      ->
      pattern ~months:[ month ] ~pos_days ~days:[ day ] ()
    | [ (pos_days, _, Month_day day); (_, _, Of); (_, _, Month month) ] ->
      pattern ~months:[ month ] ~pos_days ~days:[ day ] ()
    | _ -> `None

  let rule_d l =
    match l with
    | [ (pos_days, _, Month_day day) ] -> pattern ~pos_days ~days:[ day ] ()
    | _ -> `None

  let rule_hms l =
    match l with [ (_, _, Hms hms) ] -> pattern ~hms () | _ -> `None

  let rule_hmss l =
    match l with
    | [ (_, _, Hmss hmss) ] -> (
        match (pattern (), t_of_hmss hmss) with
        | `Some t, `Some t' -> `Some Timere.(t & t')
        | `None, _ -> `None
        | _, `None -> `None
        | `Error msg, _ -> `Error msg
        | _, `Error msg -> `Error msg)
    | _ -> `None

  let rule_d_hms l =
    match l with
    | [ (pos_days, _, Month_day day); (_, _, Hms hms) ] ->
      pattern ~pos_days ~days:[ day ] ~hms ()
    | _ -> `None

  let rule_d_hmss l =
    match l with
    | [ (pos_days, _, Month_day day); (_, _, Hmss hmss) ] -> (
        match (pattern ~pos_days ~days:[ day ] (), t_of_hmss hmss) with
        | `Some t, `Some t' -> `Some Timere.(t & t')
        | `None, _ -> `None
        | _, `None -> `None
        | `Error msg, _ -> `Error msg
        | _, `Error msg -> `Error msg)
    | _ -> `None

  let rule_md_hms l =
    match l with
    | [ (_, _, Month month); (pos_days, _, Nat day); (_, _, Hms hms) ]
    | [ (_, _, Month month); (pos_days, _, Month_day day); (_, _, Hms hms) ] ->
      pattern ~months:[ month ] ~pos_days ~days:[ day ] ~hms ()
    | _ -> `None

  let rule_ymd_hms l =
    match l with
    | [ (_, _, Ymd ((_, year), (_, month), (pos_days, day))); (_, _, Hms hms) ]
      ->
      pattern ~years:[ year ] ~months:[ month ] ~pos_days ~days:[ day ] ~hms
        ()
    | _ -> `None

  let rule_ymd_hms_to_ymd_hms l =
    match l with
    | [
      (_, _, Ymd ((_, year1), (_, month1), (pos_day1, day1)));
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Ymd ((_, year2), (_, month2), (pos_day2, day2)));
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~year:year1 ~month:month1 ~pos_day:pos_day1 ~day:day1
              ~hms:hms1 `Front,
            points ~year:year2 ~month:month2 ~pos_day:pos_day2 ~day:day2
              ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:((year2 - year1 + 1) * 366) ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_ymd_hms_to_md_hms l =
    match l with
    | [
      (_, _, Ymd ((_, year1), (_, month1), (pos_day1, day1)));
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Month month2);
      (pos_day2, _, Nat day2);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Ymd ((_, year1), (_, month1), (pos_day1, day1)));
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Month month2);
      (pos_day2, _, Month_day day2);
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~year:year1 ~month:month1 ~pos_day:pos_day1 ~day:day1
              ~hms:hms1 `Front,
            points ~month:month2 ~pos_day:pos_day2 ~day:day2 ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:366 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_ymd_hms_to_d_hms l =
    match l with
    | [
      (_, _, Ymd ((_, year1), (_, month1), (pos_day1, day1)));
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Nat day2);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Ymd ((_, year1), (_, month1), (pos_day1, day1)));
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Month_day day2);
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~year:year1 ~month:month1 ~pos_day:pos_day1 ~day:day1
              ~hms:hms1 `Front,
            points ~pos_day:pos_day2 ~day:day2 ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:366 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_ymd_hms_to_hms l =
    match l with
    | [
      (_, _, Ymd ((_, year1), (_, month1), (pos_day1, day1)));
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~year:year1 ~month:month1 ~pos_day:pos_day1 ~day:day1
              ~hms:hms1 `Front,
            points ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:366 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_md_hms_to_md_hms l =
    match l with
    | [
      (_, _, Month month1);
      (pos_day1, _, Nat day1);
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Month month2);
      (pos_day2, _, Nat day2);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Month month1);
      (pos_day1, _, Nat day1);
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Month month2);
      (pos_day2, _, Month_day day2);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Month month1);
      (pos_day1, _, Month_day day1);
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Month month2);
      (pos_day2, _, Nat day2);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Month month1);
      (pos_day1, _, Month_day day1);
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Month month2);
      (pos_day2, _, Month_day day2);
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~month:month1 ~pos_day:pos_day1 ~day:day1 ~hms:hms1 `Front,
            points ~month:month2 ~pos_day:pos_day2 ~day:day2 ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:366 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_md_hms_to_d_hms l =
    match l with
    | [
      (_, _, Month month1);
      (pos_day1, _, Nat day1);
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Nat day2);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Month month1);
      (pos_day1, _, Nat day1);
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Month_day day2);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Month month1);
      (pos_day1, _, Month_day day1);
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Nat day2);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Month month1);
      (pos_day1, _, Month_day day1);
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Month_day day2);
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~month:month1 ~pos_day:pos_day1 ~day:day1 ~hms:hms1 `Front,
            points ~pos_day:pos_day2 ~day:day2 ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:32 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_md_hms_to_hms l =
    match l with
    | [
      (_, _, Month month1);
      (pos_day1, _, Nat day1);
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Hms hms2);
    ]
    | [
      (_, _, Month month1);
      (pos_day1, _, Month_day day1);
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~month:month1 ~pos_day:pos_day1 ~day:day1 ~hms:hms1 `Front,
            points ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:32 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_d_hms_to_d_hms l =
    match l with
    | [
      (pos_day1, _, Nat day1);
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Nat day2);
      (_, _, Hms hms2);
    ]
    | [
      (pos_day1, _, Nat day1);
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Month_day day2);
      (_, _, Hms hms2);
    ]
    | [
      (pos_day1, _, Month_day day1);
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Nat day2);
      (_, _, Hms hms2);
    ]
    | [
      (pos_day1, _, Month_day day1);
      (_, _, Hms hms1);
      (_, _, To);
      (pos_day2, _, Month_day day2);
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~pos_day:pos_day1 ~day:day1 ~hms:hms1 `Front,
            points ~pos_day:pos_day2 ~day:day2 ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:32 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_d_hms_to_hms l =
    match l with
    | [
      (pos_day1, _, Nat day1); (_, _, Hms hms1); (_, _, To); (_, _, Hms hms2);
    ]
    | [
      (pos_day1, _, Month_day day1);
      (_, _, Hms hms1);
      (_, _, To);
      (_, _, Hms hms2);
    ] -> (
        match
          ( points ~pos_day:pos_day1 ~day:day1 ~hms:hms1 `Front,
            points ~hms:hms2 `Back )
        with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:2 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rule_hms_to_hms l =
    match l with
    | [ (_, _, Hms hms1); (_, _, To); (_, _, Hms hms2) ] -> (
        match (points ~hms:hms1 `Front, points ~hms:hms2 `Back) with
        | `Some p1, `Some p2 ->
          `Some
            (Timere.bounded_intervals `Whole
               (Timere.Duration.make ~days:2 ())
               p1 p2)
        | _, _ -> `None)
    | _ -> `None

  let rules : (token list -> Timere.t rule_result) list =
    [
      rule_star;
      rule_weekdays;
      rule_month_days;
      rule_month_and_days;
      rule_month;
      rule_ymd;
      rule_ym;
      rule_md;
      rule_hms;
      rule_hmss;
      rule_d;
      rule_d_hms;
      rule_d_hmss;
      rule_md_hms;
      rule_ymd_hms;
      rule_ymd_hms_to_ymd_hms;
      rule_ymd_hms_to_md_hms;
      rule_ymd_hms_to_d_hms;
      rule_ymd_hms_to_hms;
      rule_md_hms_to_md_hms;
      rule_md_hms_to_d_hms;
      rule_md_hms_to_hms;
      rule_d_hms_to_d_hms;
      rule_d_hms_to_hms;
      rule_hms_to_hms;
    ]
end

let t_of_tokens (tokens : token list) : (Timere.t, string) CCResult.t =
  let rec aux tokens rules =
    match rules with
    | [] ->
      let pos, _, _ = List.hd tokens in
      (* List.iter
       *   (fun token -> print_endline (string_of_token token))
       *   tokens; *)
      Error
        (Printf.sprintf "%s: Unrecognized token pattern" (string_of_pos pos))
    | rule :: rest -> (
        match rule tokens with
        | `Some time -> Ok time
        | `None -> aux tokens rest
        | `Error msg -> Error msg)
  in
  aux tokens Rules.rules

let t_of_ast (ast : ast) : (Timere.t, string) CCResult.t =
  let rec aux ast =
    match ast with
    | Tokens tokens -> t_of_tokens tokens
    | Unary_op (op, ast) -> (
        match op with
        | With_time_zone tz -> (
            match aux ast with
            | Error msg -> Error msg
            | Ok ast -> Ok (Timere.with_tz tz ast)))
    | Binary_op (op, ast1, ast2) -> (
        match aux ast1 with
        | Error msg -> Error msg
        | Ok time1 -> (
            match aux ast2 with
            | Error msg -> Error msg
            | Ok time2 -> (
                match op with
                | Union -> Ok (Timere.union [ time1; time2 ])
                | Inter -> Ok (Timere.inter [ time1; time2 ]))))
    | Round_robin_pick l -> (
        match l |> List.map aux |> Misc_utils.get_ok_error_list with
        | Error msg -> Error msg
        | Ok _l ->
          (* Ok (Timere.round_robin_pick l) *)
          failwith "Unimplemented")
  in
  aux ast

let parse_timere s =
  match parse_into_ast s with
  | Error msg -> Error msg
  | Ok ast -> (
      match Ast_normalize.normalize ast with
      (* match Ok ast with *)
      | Error msg -> Error msg
      | Ok ast -> t_of_ast ast)

let date_time_t_of_ast ~tz (ast : ast) : (Timere.Date_time.t, string) CCResult.t
  =
  let rec aux tz ast =
    match ast with
    | Tokens [ (_, _, Ymd ((_, year), (_, month), (_, day))); (_, _, Hms hms) ]
    | Tokens [ (_, _, Hms hms); (_, _, Ymd ((_, year), (_, month), (_, day))) ]
      -> (
          match
            Timere.Date_time.make ~year ~month ~day ~hour:hms.hour
              ~minute:hms.minute ~second:hms.second ~tz ()
          with
          | Some x -> Ok x
          | None -> Error "Invalid date time")
    | Tokens [ (_, _, Ymd ((_, year), (_, month), (_, day))) ] -> (
        match
          Timere.Date_time.make ~year ~month ~day ~hour:0 ~minute:0 ~second:0
            ~tz ()
        with
        | Some x -> Ok x
        | None -> Error "Invalid date time")
    | Unary_op (With_time_zone tz, ast) -> aux tz ast
    | _ -> Error "Unrecognized pattern"
  in
  aux tz ast

let hms_t_of_ast (ast : ast) : (Timere.hms, string) CCResult.t =
  match ast with
  | Tokens [ (_, _, Hms hms) ] -> Ok hms
  | _ -> Error "Unrecognized pattern"

let parse_date_time ?(tz = CCOpt.get_exn @@ Timere.Time_zone.local ()) s =
  match parse_into_ast s with
  | Error msg -> Error msg
  | Ok ast -> (
      match Ast_normalize.normalize ast with
      | Error msg -> Error msg
      | Ok ast -> date_time_t_of_ast ~tz ast)

let parse_hms s =
  match parse_into_ast s with
  | Error msg -> Error msg
  | Ok ast -> (
      match Ast_normalize.normalize ast with
      | Error msg -> Error msg
      | Ok ast -> hms_t_of_ast ast)

let duration_t_of_ast (ast : ast) : (Timere.Duration.t, string) CCResult.t =
  match ast with
  | Tokens [ (_, _, Duration duration) ] -> Ok duration
  | _ -> Error "Unrecognized pattern"

let parse_duration s =
  match parse_into_ast s with
  | Error msg -> Error msg
  | Ok ast -> (
      match Ast_normalize.normalize ast with
      | Error msg -> Error msg
      | Ok ast -> duration_t_of_ast ast)
