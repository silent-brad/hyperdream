module TCP = Tcpv4v6_socket
module PAF = Paf_mirage.Make (TCP)
module Server = Hyperdream.App.Make (PAF)

let hub = Hyperdream.Sse.create_hub ()
let messages : (string * string) list ref = ref []
let max_messages = 50

let datastar_js =
  Hyperdream.Assets.register ~original_path:"js/datastar.js"
    ~content:
      (match Template.read "js/datastar.js" with Some s -> s | None -> "")

let send_path =
  Hyperdream.Action.define hub "chat/send" (fun req ->
      let signals = Datastar.read_signals_from_body req.body in
      let username =
        match Yojson.Safe.Util.member "username" signals with
        | `String s when s <> "" -> s
        | _ -> "Anonymous"
      in
      let message =
        match Yojson.Safe.Util.member "message" signals with
        | `String s -> s
        | _ -> ""
      in
      if message <> "" then begin
        let msgs = !messages @ [ (username, message) ] in
        let len = List.length msgs in
        messages :=
          if len > max_messages then
            List.filteri (fun i _ -> i >= len - max_messages) msgs
          else msgs
      end;
      Lwt.return
        (Hyperdream.Action.patch_signals
           (`Assoc [ ("message", `String "") ])))

let render_messages () =
  List.map
    (fun (user, msg) ->
      Hyperdream.Html.el "div"
        ~attrs:[ ("class", "message") ]
        [
          Hyperdream.Html.el "strong"
            [ Hyperdream.Html.text (user ^ ": ") ];
          Hyperdream.Html.text msg;
        ])
    !messages
  |> Hyperdream.Html.concat

let _view =
  Hyperdream.View.define ~datastar_js hub "/" (fun _req ->
      let msgs_html = render_messages () in
      Lwt.return
        (Hyperdream.Template.render_mixed Template.index_jinja
           ~str_models:[ ("send_path", send_path) ]
           ~safe_models:[ ("messages", msgs_html) ]))

let () =
  Lwt_main.run
    (let open Lwt.Syntax in
     let ipv4_prefix = Ipaddr.V4.Prefix.of_string_exn "0.0.0.0/0" in
     let* tcp =
       TCP.connect ~ipv4_only:false ~ipv6_only:false ipv4_prefix None
     in
     let port = 8083 in
     let* http_server = PAF.init ~port tcp in
     Server.start ~port http_server)
