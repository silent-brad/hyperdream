type response =
  | No_content
  | Patch of string * Datastar.patch_element_opts
  | Patch_signals of Yojson.Safe.t

let no_content = No_content
let patch ?(opts = Datastar.default_patch_element_opts) html = Patch (html, opts)
let patch_signals json = Patch_signals json

let hashed_path name =
  let hash = Digestif.SHA256.(digest_string name |> to_hex) in
  "/" ^ String.sub hash 0 16

let define hub name (handler : Router.request -> response Lwt.t) =
  let path = hashed_path name in
  Router.add (`POST, path) (fun request ->
      let open Lwt.Syntax in
      let* resp = handler request in
      match resp with
      | No_content ->
          let* () = Sse.notify_all hub in
          Lwt.return Router.No_content
      | Patch (html, opts) -> Sse.write_action_sse request.reqd [ (html, opts) ]
      | Patch_signals signals -> Sse.patch_signals request.reqd signals);
  path
