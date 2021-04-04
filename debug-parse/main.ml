let debug_parsing () =
  let expr = "2020.1.30" in
  print_endline expr;
  print_newline ();
  print_endline "gives";
  print_newline ();
  match Timere_parse.timere expr with
  | Error msg -> print_endline msg
  | Ok timere ->
    Fmt.pr "%a@."
    Timere.pp_sexp
    timere

let debug_duration () =
  let dura = "7d" in
  match Timere_parse.duration dura with
  | Error msg -> print_endline msg
  | Ok timere ->
    Fmt.pr "%a@."
      Timere.Duration.pp
      timere

let () =
  debug_parsing ()

(* let () =
 *   debug_duration () *)
