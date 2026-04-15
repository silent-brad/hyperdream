open Lwt.Syntax

let sessions : (string, (string * string) list) Hashtbl.t = Hashtbl.create 256

let generate_id () =
  let buf = Bytes.create 20 in
  for i = 0 to 19 do
    Bytes.set buf i (Char.chr (Random.int 256))
  done;
  Base64.encode_exn ~pad:false (Bytes.to_string buf)

let cookie_name = "__Host-sid"

let parse_cookie headers =
  match H1.Headers.get headers "cookie" with
  | None -> None
  | Some cookie_str ->
      let parts = String.split_on_char ';' cookie_str in
      List.find_map
        (fun part ->
          let part = String.trim part in
          match String.split_on_char '=' part with
          | [ name; value ] when String.equal (String.trim name) cookie_name ->
              Some (String.trim value)
          | _ -> None)
        parts

let get_session headers =
  match parse_cookie headers with
  | None -> None
  | Some sid -> if Hashtbl.mem sessions sid then Some sid else None

let create_session () =
  let sid = generate_id () in
  Hashtbl.replace sessions sid [];
  sid

let set_cookie sid =
  Printf.sprintf "%s=%s; Path=/; HttpOnly; SameSite=Lax; Max-Age=86400"
    cookie_name sid

let session_data sid =
  match Hashtbl.find_opt sessions sid with Some data -> data | None -> []

let set_session_value sid key value =
  let data = session_data sid in
  let data = List.filter (fun (k, _) -> not (String.equal k key)) data in
  Hashtbl.replace sessions sid ((key, value) :: data)

let get_session_value sid key =
  let data = session_data sid in
  List.assoc_opt key data

let check_csrf (request : Router.request) =
  match request.meth with
  | `GET | `HEAD | `OPTIONS -> true
  | _ -> (
      match H1.Headers.get request.headers "sec-fetch-site" with
      | Some "same-origin" -> true
      | _ -> false)

let wrap_session (handler : Router.request -> Router.response Lwt.t)
    (request : Router.request) =
  match request.meth with
  | `GET -> (
      match get_session request.headers with
      | Some _sid -> handler request
      | None -> (
          let sid = create_session () in
          let+ resp = handler request in
          match resp with
          | Router.Html { status; headers; body } ->
              Router.Html
                {
                  status;
                  headers = ("set-cookie", set_cookie sid) :: headers;
                  body;
                }
          | other -> other))
  | _ -> (
      if not (check_csrf request) then
        Lwt.return
          (Router.Html
             { status = `Forbidden; headers = []; body = "CSRF check failed" })
      else
        match get_session request.headers with
        | Some _sid -> handler request
        | None ->
            Lwt.return
              (Router.Html
                 { status = `Forbidden; headers = []; body = "No session" }))
