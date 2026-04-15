module Make (HTTP_server : Paf_mirage.S with type ipaddr = Ipaddr.t) = struct
  let error_handler _dst ?request:_ _error _start_response = ()

  let request_handler _flow (_ipaddr, _port) reqd =
    Lwt.async (fun () ->
        let path = (H1.Reqd.request reqd).H1.Request.target in
        let parsed_path, _query = Router.parse_target path in
        match Assets.find parsed_path with
        | Some _ ->
            let open Lwt.Syntax in
            let* req = Router.make_request reqd in
            let+ resp = Assets.handler req in
            (match resp with
             | Router.Html { status; headers; body } ->
                 Router.respond_string reqd ~headers ~status ~body ()
             | _ -> ())
        | None -> Router.dispatch reqd)

  let start ?(port = 8080) t =
    let service =
      HTTP_server.http_service ~error_handler request_handler
    in
    let (`Initialized th) = HTTP_server.serve service t in
    Printf.printf "Hyperdream listening on port %d\n%!" port;
    th
end
