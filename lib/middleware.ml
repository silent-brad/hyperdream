type t =
  (Router.request -> Router.response Lwt.t) ->
  Router.request ->
  Router.response Lwt.t

let compose (middlewares : t list)
    (handler : Router.request -> Router.response Lwt.t) =
  List.fold_right (fun mw h -> mw h) middlewares handler

let security_headers : t =
 fun handler request ->
  let open Lwt.Syntax in
  let+ resp = handler request in
  match resp with
  | Router.Html { status; headers; body } ->
      Router.Html
        {
          status;
          headers =
            [
              ("x-content-type-options", "nosniff");
              ("x-frame-options", "DENY");
              ("referrer-policy", "strict-origin-when-cross-origin");
            ]
            @ headers;
          body;
        }
  | other -> other

let error_handler : t =
 fun handler request ->
  Lwt.catch
    (fun () -> handler request)
    (fun exn ->
      let msg = Printexc.to_string exn in
      Printf.eprintf "Hyperdream error: %s\n%!" msg;
      Lwt.return
        (Router.Html
           {
             status = `Internal_server_error;
             headers = [];
             body = "Internal Server Error";
           }))

let default_stack : t list =
  [ error_handler; security_headers; Session.wrap_session ]
