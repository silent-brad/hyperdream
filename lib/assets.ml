let registered : (string, string * string) Hashtbl.t = Hashtbl.create 32

let content_type_of_ext path =
  let ext =
    match String.rindex_opt path '.' with
    | Some i -> String.sub path (i + 1) (String.length path - i - 1)
    | None -> ""
  in
  match String.lowercase_ascii ext with
  | "html" -> "text/html; charset=utf-8"
  | "css" -> "text/css; charset=utf-8"
  | "js" -> "application/javascript; charset=utf-8"
  | "json" -> "application/json"
  | "png" -> "image/png"
  | "jpg" | "jpeg" -> "image/jpeg"
  | "gif" -> "image/gif"
  | "svg" -> "image/svg+xml"
  | "ico" -> "image/x-icon"
  | "woff" -> "font/woff"
  | "woff2" -> "font/woff2"
  | "ttf" -> "font/ttf"
  | "otf" -> "font/otf"
  | _ -> "application/octet-stream"

let digest_path content =
  let hash = Digestif.SHA256.(digest_string content |> to_hex) in
  "/" ^ String.sub hash 0 16

let register ~original_path ~content =
  let ct = content_type_of_ext original_path in
  let path = digest_path content in
  Hashtbl.replace registered path (ct, content);
  path

let register_raw ~path ~content_type ~content =
  Hashtbl.replace registered path (content_type, content);
  path

let find path = Hashtbl.find_opt registered path

let handler (request : Router.request) =
  match find request.path with
  | Some (content_type, body) ->
      Lwt.return
        (Router.Html
           {
             status = `OK;
             headers =
               [
                 ("content-type", content_type);
                 ("cache-control", "max-age=31536000, immutable");
               ];
             body;
           })
  | None -> Lwt.return Router.Not_found

let register_embedded_files files =
  List.map
    (fun (original_path, content) -> register ~original_path ~content)
    files
