module TCP = Tcpv4v6_socket
module PAF = Paf_mirage.Make (TCP)
module Server = Hyperdream.App.Make (PAF)

let () =
  Lwt_main.run
    (let open Lwt.Syntax in
     let ipv4_prefix = Ipaddr.V4.Prefix.of_string_exn "0.0.0.0/0" in
     let* tcp =
       TCP.connect ~ipv4_only:false ~ipv6_only:false ipv4_prefix None
     in
     let port = 8080 in
     let* http_server = PAF.init ~port tcp in
     Server.start ~port http_server)
