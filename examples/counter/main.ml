module TCP = Tcpv4v6_socket
module PAF = Paf_mirage.Make (TCP)
module Server = Hyperdream.App.Make (PAF)

let hub = Hyperdream.Sse.create_hub ()
let counter = ref 0

let datastar_js =
  Hyperdream.Assets.register ~original_path:"js/datastar.js"
    ~content:
      (match Template.read "js/datastar.js" with Some s -> s | None -> "")

let inc_path =
  Hyperdream.Action.define hub "counter/inc" (fun _req ->
      incr counter;
      Lwt.return Hyperdream.Action.no_content)

let dec_path =
  Hyperdream.Action.define hub "counter/dec" (fun _req ->
      decr counter;
      Lwt.return Hyperdream.Action.no_content)

let reset_path =
  Hyperdream.Action.define hub "counter/reset" (fun _req ->
      counter := 0;
      Lwt.return Hyperdream.Action.no_content)

let _view =
  Hyperdream.View.define ~datastar_js hub "/" (fun _req ->
      Lwt.return
        (Hyperdream.Template.render_string Template.index_jinja
           ~models:
             [
               ("count", string_of_int !counter);
               ("inc_path", inc_path);
               ("dec_path", dec_path);
               ("reset_path", reset_path);
             ]))

let () =
  Lwt_main.run
    (let open Lwt.Syntax in
     let ipv4_prefix = Ipaddr.V4.Prefix.of_string_exn "0.0.0.0/0" in
     let* tcp =
       TCP.connect ~ipv4_only:false ~ipv6_only:false ipv4_prefix None
     in
     let* http_server = PAF.init ~port:8080 tcp in
     Server.start ~port:8080 http_server)
