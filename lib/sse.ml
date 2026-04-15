open Lwt.Syntax

type client = {
  notify : unit Lwt_condition.t;
  mutable alive : bool;
  mutable last_view_hash : string;
}

type hub = { clients : client list ref; mutex : Lwt_mutex.t }

let create_hub () = { clients = ref []; mutex = Lwt_mutex.create () }

let add_client hub client =
  Lwt_mutex.with_lock hub.mutex (fun () ->
      hub.clients := client :: !(hub.clients);
      Lwt.return_unit)

let remove_client hub client =
  Lwt_mutex.with_lock hub.mutex (fun () ->
      hub.clients := List.filter (fun c -> c != client) !(hub.clients);
      Lwt.return_unit)

let notify_all hub =
  Lwt_mutex.with_lock hub.mutex (fun () ->
      List.iter
        (fun c -> if c.alive then Lwt_condition.signal c.notify ())
        !(hub.clients);
      Lwt.return_unit)

let flush_body body =
  let p, r = Lwt.wait () in
  H1.Body.Writer.flush body (fun () -> Lwt.wakeup_later r ());
  p

let write_and_flush body data =
  H1.Body.Writer.write_string body data;
  flush_body body

let respond_sse reqd ~render hub =
  let headers =
    H1.Headers.of_list
      ([ ("x-accel-buffering", "no"); ("transfer-encoding", "chunked") ]
      @ Datastar.sse_headers)
  in
  let response = H1.Response.create ~headers `OK in
  let body =
    H1.Reqd.respond_with_streaming ~flush_headers_immediately:true reqd response
  in
  let client =
    { notify = Lwt_condition.create (); alive = true; last_view_hash = "" }
  in
  Lwt.async (fun () ->
      let* () = add_client hub client in
      Lwt.finalize
        (fun () ->
          let write_frame () =
            let buf = Buffer.create 512 in
            let sse =
              Datastar.create ~write:(fun s -> Buffer.add_string buf s) ()
            in
            let* html = render () in
            let hash =
              Digestif.SHA256.(digest_string html |> to_hex) |> fun s ->
              String.sub s 0 16
            in
            if String.equal hash client.last_view_hash then Lwt.return_unit
            else begin
              client.last_view_hash <- hash;
              Datastar.patch_elements sse html ~id:hash
                ~opts:
                  {
                    Datastar.default_patch_element_opts with
                    selector = Some "#morph";
                    mode = Datastar.Outer;
                  };
              let data = Buffer.contents buf in
              Lwt.catch
                (fun () -> write_and_flush body data)
                (fun _exn ->
                  client.alive <- false;
                  Lwt.return_unit)
            end
          in
          let rec loop () =
            let* () = Lwt_condition.wait client.notify in
            if not client.alive then begin
              H1.Body.Writer.close body;
              Lwt.return_unit
            end
            else
              Lwt.catch
                (fun () ->
                  let* () = write_frame () in
                  loop ())
                (fun _exn ->
                  client.alive <- false;
                  H1.Body.Writer.close body;
                  Lwt.return_unit)
          in
          Lwt.catch
            (fun () ->
              let* () = write_frame () in
              loop ())
            (fun _exn ->
              client.alive <- false;
              H1.Body.Writer.close body;
              Lwt.return_unit))
        (fun () -> remove_client hub client));
  Lwt.return Router.Streaming

let write_action_sse reqd fragments =
  let headers =
    H1.Headers.of_list
      ([ ("x-accel-buffering", "no"); ("transfer-encoding", "chunked") ]
      @ Datastar.sse_headers)
  in
  let response = H1.Response.create ~headers `OK in
  let body =
    H1.Reqd.respond_with_streaming ~flush_headers_immediately:true reqd response
  in
  let buf = Buffer.create 256 in
  let sse = Datastar.create ~write:(fun s -> Buffer.add_string buf s) () in
  List.iter
    (fun (html, opts) -> Datastar.patch_elements sse html ~opts)
    fragments;
  let data = Buffer.contents buf in
  let* () = write_and_flush body data in
  H1.Body.Writer.close body;
  Lwt.return Router.Streaming

let patch_signals reqd signals =
  let headers =
    H1.Headers.of_list
      ([ ("x-accel-buffering", "no"); ("transfer-encoding", "chunked") ]
      @ Datastar.sse_headers)
  in
  let response = H1.Response.create ~headers `OK in
  let body =
    H1.Reqd.respond_with_streaming ~flush_headers_immediately:true reqd response
  in
  let buf = Buffer.create 256 in
  let sse = Datastar.create ~write:(fun s -> Buffer.add_string buf s) () in
  Datastar.patch_signals_json sse signals;
  let data = Buffer.contents buf in
  let* () = write_and_flush body data in
  H1.Body.Writer.close body;
  Lwt.return Router.Streaming
