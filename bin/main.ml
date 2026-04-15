module TCP = Tcpv4v6_socket
module PAF = Paf_mirage.Make (TCP)
module Server = Hyperdream.App.Make (PAF)

let run port =
  Lwt_main.run
    (let open Lwt.Syntax in
     let ipv4_prefix = Ipaddr.V4.Prefix.of_string_exn "0.0.0.0/0" in
     let* tcp =
       TCP.connect ~ipv4_only:false ~ipv6_only:false ipv4_prefix None
     in
     let* http_server = PAF.init ~port tcp in
     Server.start ~port http_server)

let () =
  let open Cmdliner in
  let port =
    Arg.(
      value & opt int 8080
      & info [ "p"; "port" ] ~docv:"PORT" ~doc:"Port to listen on.")
  in
  let cmd =
    Cmd.v
      (Cmd.info "hyperdream" ~doc:"Hyperdream dev server")
      Term.(const run $ port)
  in
  exit (Cmd.eval cmd)
