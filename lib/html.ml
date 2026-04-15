let doctype = "<!DOCTYPE html>"

let el ?(attrs = []) tag children =
  let buf = Buffer.create 256 in
  Buffer.add_char buf '<';
  Buffer.add_string buf tag;
  List.iter
    (fun (k, v) ->
      Buffer.add_char buf ' ';
      Buffer.add_string buf k;
      Buffer.add_string buf "=\"";
      Buffer.add_string buf v;
      Buffer.add_char buf '"')
    attrs;
  Buffer.add_char buf '>';
  List.iter (Buffer.add_string buf) children;
  Buffer.add_string buf "</";
  Buffer.add_string buf tag;
  Buffer.add_char buf '>';
  Buffer.contents buf

let void_el ?(attrs = []) tag =
  let buf = Buffer.create 64 in
  Buffer.add_char buf '<';
  Buffer.add_string buf tag;
  List.iter
    (fun (k, v) ->
      Buffer.add_char buf ' ';
      Buffer.add_string buf k;
      Buffer.add_string buf "=\"";
      Buffer.add_string buf v;
      Buffer.add_char buf '"')
    attrs;
  Buffer.add_string buf " />";
  Buffer.contents buf

let text s =
  let buf = Buffer.create (String.length s) in
  String.iter
    (function
      | '&' -> Buffer.add_string buf "&amp;"
      | '<' -> Buffer.add_string buf "&lt;"
      | '>' -> Buffer.add_string buf "&gt;"
      | '"' -> Buffer.add_string buf "&quot;"
      | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

let raw s = s
let concat parts = String.concat "" parts

let shim_page ?(lang = "en") ?(head_extra = "") ~datastar_js ~sse_path () =
  let on_load_js =
    Printf.sprintf "@post('%s',{retryMaxCount:Infinity})" sse_path
  in
  concat
    [
      doctype;
      el "html"
        ~attrs:[ ("lang", lang) ]
        [
          el "head"
            [
              void_el "meta" ~attrs:[ ("charset", "utf-8") ];
              void_el "meta"
                ~attrs:
                  [
                    ("name", "viewport");
                    ("content", "width=device-width,initial-scale=1");
                  ];
              el "script"
                ~attrs:
                  [
                    ("defer", "true"); ("type", "module"); ("src", datastar_js);
                  ]
                [];
              raw head_extra;
            ];
          el "body"
            [
              el "div"
                ~attrs:
                  [
                    ("data-init", on_load_js);
                    ("data-on:online__window", on_load_js);
                  ]
                [];
              el "main" ~attrs:[ ("id", "morph") ] [];
            ];
        ];
    ]
