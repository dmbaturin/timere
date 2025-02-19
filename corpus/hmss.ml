let texts =
  [ "10am"; "10:15"; "20:30"; "23:59:59"; "10:59:59am"; "10:59:59 pm" ]

let () =
  List.iteri
    (fun i text ->
       Printf.printf "%d. %S\n" i text;
       match Timere_parse.hms text with
       | Ok hms -> Fmt.pr "  Ok %a\n\n%!" Timere.pp_hms hms
       | Error msg ->
         Printf.printf "  Error %s\n" msg;
         print_endline "  ^^^^^";
         print_newline ())
    texts
