open Lwt.Syntax

type t = {
  data : (string, string) Hashtbl.t;
  mutex : Lwt_mutex.t;
  on_change : (unit -> unit Lwt.t) option ref;
}

let key_of_path path = String.concat "/" path

let create () =
  Lwt.return
    {
      data = Hashtbl.create 128;
      mutex = Lwt_mutex.create ();
      on_change = ref None;
    }

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
  fire store

let remove store path =
  let* () =
    Lwt_mutex.with_lock store.mutex (fun () ->
        Hashtbl.remove store.data (key_of_path path);
        Lwt.return_unit)
  in
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
