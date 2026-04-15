module Router : sig
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

  val add : meth * string -> handler -> unit
  val find : meth -> string -> handler option
  val parse_target : string -> string * string option
  val make_request : H1.Reqd.t -> request Lwt.t
  val respond_string : H1.Reqd.t -> ?headers:(string * string) list ->
    status:H1.Status.t -> body:string -> unit -> unit
  val dispatch : H1.Reqd.t -> unit Lwt.t
end

module Sse : sig
  type client
  type hub

  val create_hub : unit -> hub
  val notify_all : hub -> unit Lwt.t
  val respond_sse : H1.Reqd.t -> render:(unit -> string Lwt.t) -> hub ->
    Router.response Lwt.t
  val write_action_sse : H1.Reqd.t ->
    (string * Datastar.patch_element_opts) list -> Router.response Lwt.t
  val patch_signals : H1.Reqd.t -> Yojson.Safe.t -> Router.response Lwt.t
end

module Html : sig
  val doctype : string
  val el : ?attrs:(string * string) list -> string -> string list -> string
  val void_el : ?attrs:(string * string) list -> string -> string
  val text : string -> string
  val raw : string -> string
  val concat : string list -> string
  val shim_page : ?lang:string -> ?head_extra:string ->
    datastar_js:string -> sse_path:string -> unit -> string
end

module Template : sig
  val render_string : string -> models:(string * string) list -> string
  val render_file : string -> models:(string * string) list -> string
  val render_with_raw : string -> models:(string * string) list -> string
  val render_mixed : string -> str_models:(string * string) list ->
    safe_models:(string * string) list -> string
end

module Assets : sig
  val register : original_path:string -> content:string -> string
  val register_raw : path:string -> content_type:string -> content:string -> string
  val find : string -> (string * string) option
  val handler : Router.request -> Router.response Lwt.t
  val register_embedded_files : (string * string) list -> string list
end

module Session : sig
  val get_session : H1.Headers.t -> string option
  val create_session : unit -> string
  val get_session_value : string -> string -> string option
  val set_session_value : string -> string -> string -> unit
  val check_csrf : Router.request -> bool
  val wrap_session : (Router.request -> Router.response Lwt.t) ->
    Router.request -> Router.response Lwt.t
end

module Middleware : sig
  type t = (Router.request -> Router.response Lwt.t) ->
    Router.request -> Router.response Lwt.t

  val compose : t list -> (Router.request -> Router.response Lwt.t) ->
    Router.request -> Router.response Lwt.t
  val security_headers : t
  val error_handler : t
  val default_stack : t list
end

module Store : sig
  type t

  val create : ?path:string -> unit -> t Lwt.t
  val get : t -> string list -> string option Lwt.t
  val set : t -> string list -> string -> unit Lwt.t
  val remove : t -> string list -> unit Lwt.t
  val list : t -> string list -> string list Lwt.t
  val on_change : t -> (unit -> unit Lwt.t) -> unit
  val connect_hub : t -> Sse.hub -> unit
  val key_of_path : string list -> string
end

module View : sig
  val define : ?shim_head:string -> datastar_js:string -> Sse.hub ->
    string -> (Router.request -> string Lwt.t) -> string
end

module Action : sig
  type response =
    | No_content
    | Patch of string * Datastar.patch_element_opts
    | Patch_signals of Yojson.Safe.t

  val no_content : response
  val patch : ?opts:Datastar.patch_element_opts -> string -> response
  val patch_signals : Yojson.Safe.t -> response
  val hashed_path : string -> string
  val define : Sse.hub -> string -> (Router.request -> response Lwt.t) -> string
end

module App : sig
  module Make (HTTP_server : Paf_mirage.S with type ipaddr = Ipaddr.t) : sig
    val start : ?port:int -> HTTP_server.t -> unit Lwt.t
  end
end
