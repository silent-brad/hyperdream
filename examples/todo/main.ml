open Hyperdream

module Tmpl = Hyperdream.Template
module Embedded = Template

module TCP = Tcpv4v6_socket
module PAF = Paf_mirage.Make (TCP)
module Server = App.Make (PAF)

let get_query_param query key =
  match query with
  | None -> None
  | Some qs ->
    let parts = String.split_on_char '&' qs in
    List.find_map (fun part ->
      match String.split_on_char '=' part with
      | [k; v] when String.equal k key -> Some v
      | _ -> None) parts

let render_todo toggle_path delete_path (id, text, done_) =
  Html.el "div" ~attrs:[("class", if done_ then "todo done" else "todo")] [
    Html.el "span" [Html.text text];
    Html.el "button" ~attrs:[("data-on:click",
      Printf.sprintf "@post('%s?id=%s')" toggle_path id)]
      [Html.text (if done_ then "Undo" else "Done")];
    Html.el "button" ~attrs:[("data-on:click",
      Printf.sprintf "@post('%s?id=%s')" delete_path id)]
      [Html.text "Delete"];
  ]

let () =
  Lwt_main.run begin
    let open Lwt.Syntax in
    let hub = Sse.create_hub () in
    let* store = Store.create () in
    Store.connect_hub store hub;
    let next_id = ref 0 in

    let add_path = Action.define hub "add_todo" (fun request ->
      let signals = Yojson.Safe.from_string request.Router.body in
      let text = match signals with
        | `Assoc pairs ->
          (match List.assoc_opt "todo_input" pairs with
           | Some (`String s) -> s
           | _ -> "")
        | _ -> ""
      in
      if String.length text > 0 then begin
        let id = string_of_int !next_id in
        incr next_id;
        let value = `Assoc [("text", `String text); ("done", `Bool false)] in
        let* () = Store.set store ["todos"; id] (Yojson.Safe.to_string value) in
        Lwt.return (Action.patch_signals (`Assoc [("todo_input", `String "")]))
      end else
        Lwt.return Action.no_content
    ) in

    let toggle_path = Action.define hub "toggle_todo" (fun request ->
      match get_query_param request.Router.query "id" with
      | None -> Lwt.return Action.no_content
      | Some id ->
        let* data = Store.get store ["todos"; id] in
        match data with
        | None -> Lwt.return Action.no_content
        | Some json_str ->
          let json = Yojson.Safe.from_string json_str in
          let toggled = match json with
            | `Assoc pairs ->
              let pairs = List.map (fun (k, v) ->
                if String.equal k "done" then
                  (k, `Bool (not (v = `Bool true)))
                else (k, v)) pairs
              in
              `Assoc pairs
            | other -> other
          in
          let* () = Store.set store ["todos"; id] (Yojson.Safe.to_string toggled) in
          Lwt.return Action.no_content
    ) in

    let delete_path = Action.define hub "delete_todo" (fun request ->
      match get_query_param request.Router.query "id" with
      | None -> Lwt.return Action.no_content
      | Some id ->
        let* () = Store.remove store ["todos"; id] in
        Lwt.return Action.no_content
    ) in

    let datastar_js = Assets.register ~original_path:"js/datastar.js"
      ~content:(match Embedded.read "js/datastar.js" with Some s -> s | None -> "") in

    let _view_path = View.define ~datastar_js hub "/" (fun _request ->
      let* ids = Store.list store ["todos"] in
      let* todos = Lwt_list.filter_map_s (fun id ->
        let+ data = Store.get store ["todos"; id] in
        match data with
        | None -> None
        | Some json_str ->
          let json = Yojson.Safe.from_string json_str in
          let text = match json with
            | `Assoc pairs ->
              (match List.assoc_opt "text" pairs with
               | Some (`String s) -> s | _ -> "")
            | _ -> ""
          in
          let done_ = match json with
            | `Assoc pairs ->
              (match List.assoc_opt "done" pairs with
               | Some (`Bool b) -> b | _ -> false)
            | _ -> false
          in
          Some (id, text, done_)
      ) ids in
      let todo_html = Html.concat
        (List.map (render_todo toggle_path delete_path) todos) in
      let body = Tmpl.render_mixed Embedded.index_jinja
        ~str_models:[
          ("add_path", add_path);
          ("toggle_path", toggle_path);
          ("delete_path", delete_path);
        ]
        ~safe_models:[("todo_list", todo_html)]
      in
      Lwt.return body
    ) in

    let ipv4_prefix = Ipaddr.V4.Prefix.of_string_exn "0.0.0.0/0" in
    let* tcp = TCP.connect ~ipv4_only:false ~ipv6_only:false ipv4_prefix None in
    let port = 8082 in
    let* http_server = PAF.init ~port tcp in
    Server.start ~port http_server
  end
