let define ?(shim_head = "") ~datastar_js hub path
    (render : Router.request -> string Lwt.t) =
  let shim_html =
    Html.shim_page ~head_extra:shim_head ~datastar_js ~sse_path:path ()
  in
  Router.add (`GET, path) (fun _request ->
      Lwt.return
        (Router.Html
           {
             status = `OK;
             headers = [ ("content-type", "text/html; charset=utf-8") ];
             body = shim_html;
           }));
  Router.add (`POST, path) (fun request ->
      Sse.respond_sse request.reqd hub ~render:(fun () -> render request));
  path
