module Embedded = Template
open Hyperdream
module Tmpl = Hyperdream.Template
module TCP = Tcpv4v6_socket
module PAF = Paf_mirage.Make (TCP)
module Server = App.Make (PAF)

let max_messages = 50

let render_messages msgs =
  List.map
    (fun (_id, user, msg) ->
      Html.el "div"
        ~attrs:[ ("class", "message") ]
        [ Html.el "strong" [ Html.text (user ^ ": ") ]; Html.text msg ])
    msgs
  |> Html.concat

let () =
  Lwt_main.run
    (let open Lwt.Syntax in
     let hub = Sse.create_hub () in
     let* store = Store.create ~path:"chat.db" () in
     Store.connect_hub store hub;
     let* existing_ids = Store.list store [ "messages" ] in
     let max_existing =
       List.fold_left
         (fun acc id ->
           match int_of_string_opt id with Some n -> max acc n | None -> acc)
         (-1) existing_ids
     in
     let next_id = ref (max_existing + 1) in

     let datastar_js =
       Assets.register ~original_path:"js/datastar.js"
         ~content:
           (match Embedded.read "js/datastar.js" with
           | Some s -> s
           | None -> "")
     in

     let css_path =
       Assets.register ~original_path:"css/style.css"
         ~content:
           (match Embedded.read "css/style.css" with Some s -> s | None -> "")
     in

     let send_path =
       Action.define hub "chat/send" (fun req ->
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
           if message <> "" then (
             let id = string_of_int !next_id in
             incr next_id;
             let value =
               `Assoc
                 [
                   ("username", `String username); ("message", `String message);
                 ]
             in
             let* () =
               Store.set store [ "messages"; id ] (Yojson.Safe.to_string value)
             in
             let* ids = Store.list store [ "messages" ] in
             let len = List.length ids in
             let* () =
               if len > max_messages then
                 let sorted =
                   List.sort
                     (fun a b -> compare (int_of_string a) (int_of_string b))
                     ids
                 in
                 let to_remove =
                   List.filteri (fun i _ -> i < len - max_messages) sorted
                 in
                 Lwt_list.iter_s
                   (fun rid -> Store.remove store [ "messages"; rid ])
                   to_remove
               else Lwt.return_unit
             in
             Lwt.return
               (Action.patch_signals (`Assoc [ ("message", `String "") ])))
           else Lwt.return Action.no_content)
     in

     let load_messages () =
       let* ids = Store.list store [ "messages" ] in
       let sorted =
         List.sort (fun a b -> compare (int_of_string a) (int_of_string b)) ids
       in
       Lwt_list.filter_map_s
         (fun id ->
           let+ data = Store.get store [ "messages"; id ] in
           match data with
           | None -> None
           | Some json_str ->
               let json = Yojson.Safe.from_string json_str in
               let username =
                 match json with
                 | `Assoc pairs -> (
                     match List.assoc_opt "username" pairs with
                     | Some (`String s) -> s
                     | _ -> "Anonymous")
                 | _ -> "Anonymous"
               in
               let message =
                 match json with
                 | `Assoc pairs -> (
                     match List.assoc_opt "message" pairs with
                     | Some (`String s) -> s
                     | _ -> "")
                 | _ -> ""
               in
               Some (id, username, message))
         sorted
     in

     let _view_path =
       View.define
         ~shim_head:
           (Printf.sprintf {|<link rel="stylesheet" href="%s">|} css_path)
         ~datastar_js hub "/" (fun _req ->
           let* msgs = load_messages () in
           let msgs_html = render_messages msgs in
           Lwt.return
             (Tmpl.render_mixed Embedded.index_jinja
                ~str_models:[ ("send_path", send_path) ]
                ~safe_models:[ ("messages", msgs_html) ]))
     in

     let ipv4_prefix = Ipaddr.V4.Prefix.of_string_exn "0.0.0.0/0" in
     let* tcp =
       TCP.connect ~ipv4_only:false ~ipv6_only:false ipv4_prefix None
     in
     let port = 8083 in
     let* http_server = PAF.init ~port tcp in
     Server.start ~port http_server)
