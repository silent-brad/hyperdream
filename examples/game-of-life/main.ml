module TCP = Tcpv4v6_socket
module PAF = Paf_mirage.Make (TCP)
module Server = Hyperdream.App.Make (PAF)

let hub = Hyperdream.Sse.create_hub ()
let board = ref (Game.random_board ())
let board_cache = ref (Render.board_html !board)

let datastar_js =
  Hyperdream.Assets.register ~original_path:"js/datastar.js"
    ~content:
      (match Template.read "js/datastar.js" with Some s -> s | None -> "")

let css_path =
  Hyperdream.Assets.register ~original_path:"css/style.css"
    ~content:
      (match Template.read "css/style.css" with Some s -> s | None -> "")

let get_id query =
  match query with
  | None -> None
  | Some qs ->
      let parts = String.split_on_char '&' qs in
      List.find_map
        (fun part ->
          match String.split_on_char '=' part with
          | [ "id"; v ] -> ( try Some (int_of_string v) with _ -> None)
          | _ -> None)
        parts

let tap_path =
  Hyperdream.Action.define hub "gol/tap" (fun req ->
      (match get_id req.Hyperdream.Router.query with
      | Some id ->
          let color = 1 + Random.int 6 in
          Game.fill_cross !board id color;
          board_cache := Render.board_html !board
      | None -> ());
      Lwt.return Hyperdream.Action.no_content)

let refresh_path =
  Hyperdream.Action.define hub "gol/refresh" (fun _req ->
      board := Game.random_board ();
      board_cache := Render.board_html !board;
      Lwt.return Hyperdream.Action.no_content)

let _view =
  Hyperdream.View.define
    ~shim_head:(Printf.sprintf {|<link rel="stylesheet" href="%s">|} css_path)
    ~datastar_js hub "/" (fun _req ->
      let board_frag = Render.board_fragment ~tap_path !board_cache in
      Lwt.return
        (Hyperdream.Html.el "main"
           ~attrs:[ ("id", "morph") ]
           [
             Hyperdream.Html.raw board_frag;
             Hyperdream.Html.el "div"
               ~attrs:[ ("class", "controls") ]
               [
                 Hyperdream.Html.el "button"
                   ~attrs:
                     [
                       ( "data-on:click",
                         Printf.sprintf "@post('%s')" refresh_path );
                     ]
                   [ Hyperdream.Html.text "Refresh" ];
               ];
           ]))

let game_loop () =
  let open Lwt.Syntax in
  let rec loop () =
    let* () = Lwt_unix.sleep 0.2 in
    board := Game.next_generation !board;
    board_cache := Render.board_html !board;
    let* () = Hyperdream.Sse.notify_all hub in
    loop ()
  in
  loop ()

let () =
  Lwt_main.run
    (let open Lwt.Syntax in
     Lwt.async game_loop;
     let ipv4_prefix = Ipaddr.V4.Prefix.of_string_exn "0.0.0.0/0" in
     let* tcp =
       TCP.connect ~ipv4_only:false ~ipv6_only:false ipv4_prefix None
     in
     let port = 8081 in
     let* http_server = PAF.init ~port tcp in
     Server.start ~port http_server)
