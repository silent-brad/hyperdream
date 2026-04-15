open Lwt.Syntax

type t = {
  data : (string, string) Hashtbl.t;
  mutex : Lwt_mutex.t;
  on_change : (unit -> unit Lwt.t) option ref;
  persist_path : string option;
}

let key_of_path path = String.concat "/" path

let save_to_disk store =
  match store.persist_path with
  | None -> Lwt.return_unit
  | Some path ->
      let pairs =
        Hashtbl.fold (fun k v acc -> (k, `String v) :: acc) store.data []
      in
      let json = Yojson.Safe.to_string (`Assoc pairs) in
      let* oc = Lwt_io.open_file ~mode:Lwt_io.Output path in
      let* () = Lwt_io.write oc json in
      Lwt_io.close oc

let load_from_disk store =
  match store.persist_path with
  | None -> Lwt.return_unit
  | Some path -> (
      Lwt.catch
        (fun () ->
          let* ic = Lwt_io.open_file ~mode:Lwt_io.Input path in
          let* contents = Lwt_io.read ic in
          let* () = Lwt_io.close ic in
          (match Yojson.Safe.from_string contents with
          | `Assoc pairs ->
              List.iter
                (fun (k, v) ->
                  match v with
                  | `String s -> Hashtbl.replace store.data k s
                  | _ -> ())
                pairs
          | _ -> ());
          Lwt.return_unit)
        (fun _exn -> Lwt.return_unit))

let create ?path () =
  let store =
    {
      data = Hashtbl.create 128;
      mutex = Lwt_mutex.create ();
      on_change = ref None;
      persist_path = path;
    }
  in
  let* () = load_from_disk store in
  Lwt.return store

let fire store =
  match !(store.on_change) with
  | Some f -> f ()
  | None -> Lwt.return_unit

let get store path =
  Lwt_mutex.with_lock store.mutex (fun () ->
      Lwt.return (Hashtbl.find_opt store.data (key_of_path path)))

let set store path value =
  let* () =
    Lwt_mutex.with_lock store.mutex (fun () ->
        Hashtbl.replace store.data (key_of_path path) value;
        Lwt.return_unit)
  in
  let* () = save_to_disk store in
  fire store

let remove store path =
  let* () =
    Lwt_mutex.with_lock store.mutex (fun () ->
        Hashtbl.remove store.data (key_of_path path);
        Lwt.return_unit)
  in
  let* () = save_to_disk store in
  fire store

let list store path =
  let prefix = key_of_path path in
  let prefix_len = String.length prefix in
  Lwt_mutex.with_lock store.mutex (fun () ->
      let items =
        Hashtbl.fold
          (fun k _v acc ->
            if String.length k > prefix_len
               && String.sub k 0 prefix_len = prefix
               && k.[prefix_len] = '/'
            then
              let rest = String.sub k (prefix_len + 1) (String.length k - prefix_len - 1) in
              match String.split_on_char '/' rest with
              | step :: _ ->
                  if List.mem step acc then acc else step :: acc
              | [] -> acc
            else acc)
          store.data []
      in
      Lwt.return items)

let on_change store callback = store.on_change := Some callback
let connect_hub store hub = on_change store (fun () -> Sse.notify_all hub)
