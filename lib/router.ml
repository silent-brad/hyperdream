open Lwt.Syntax

type meth = [ `GET | `POST | `PUT | `DELETE ]

type request = {
  meth : H1.Method.t;
  path : string;
  query : string option;
  headers : H1.Headers.t;
  body : string;
  reqd : H1.Reqd.t;
}

type response =
  | Html of {
      status : H1.Status.t;
      headers : (string * string) list;
      body : string;
    }
  | Streaming
  | No_content
  | Not_found

type handler = request -> response Lwt.t
type route = meth * string

let routes : (route, handler) Hashtbl.t = Hashtbl.create 64

let add (route : route) (handler : handler) =
  Hashtbl.replace routes route handler

let find (meth : meth) (path : string) : handler option =
  Hashtbl.find_opt routes (meth, path)

let parse_target target =
  match String.split_on_char '?' target with
  | [ path ] -> (path, None)
  | path :: rest -> (path, Some (String.concat "?" rest))
  | [] -> ("/", None)

let make_request reqd =
  let req = H1.Reqd.request reqd in
  let target = req.H1.Request.target in
  let path, query = parse_target target in
  let meth = req.H1.Request.meth in
  let headers = req.H1.Request.headers in
  let body_buf = Buffer.create 256 in
  let body_reader = H1.Reqd.request_body reqd in
  let+ body =
    let p, r = Lwt.wait () in
    let rec read () =
      H1.Body.Reader.schedule_read body_reader
        ~on_eof:(fun () -> Lwt.wakeup_later r (Buffer.contents body_buf))
        ~on_read:(fun bigstr ~off ~len ->
          let bytes = Bigstringaf.substring bigstr ~off ~len in
          Buffer.add_string body_buf bytes;
          read ())
    in
    read ();
    p
  in
  { meth; path; query; headers; body; reqd }

let respond_string reqd ?(headers = []) ~status ~body () =
  let content_length = String.length body in
  let h1_headers =
    H1.Headers.of_list
      (("content-length", string_of_int content_length) :: headers)
  in
  let response = H1.Response.create ~headers:h1_headers status in
  H1.Reqd.respond_with_string reqd response body

let dispatch reqd =
  let* request = make_request reqd in
  let meth =
    match request.meth with
    | `GET -> Some `GET
    | `POST -> Some `POST
    | `PUT -> Some `PUT
    | `DELETE -> Some `DELETE
    | _ -> None
  in
  let path = Datastar.path_of_target request.path in
  let handler = match meth with Some m -> find m path | None -> None in
  match handler with
  | Some h -> (
      let+ resp = h request in
      match resp with
      | Html { status; headers; body } ->
          respond_string reqd ~headers ~status ~body ()
      | Streaming -> ()
      | No_content ->
          let response = H1.Response.create `No_content in
          H1.Reqd.respond_with_string reqd response ""
      | Not_found -> respond_string reqd ~status:`Not_found ~body:"Not Found" ()
      )
  | None ->
      respond_string reqd ~status:`Not_found ~body:"Not Found" ();
      Lwt.return_unit
