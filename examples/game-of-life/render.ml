let board_html board =
  let buf = Buffer.create (Game.num_cells * 60) in
  for i = 0 to Game.num_cells - 1 do
    let c = Game.color_name board.(i) in
    Buffer.add_string buf "<div class=\"tile ";
    Buffer.add_string buf c;
    Buffer.add_string buf "\" data-id=\"";
    Buffer.add_string buf (string_of_int i);
    Buffer.add_string buf "\"></div>"
  done;
  Buffer.contents buf

let board_fragment ~tap_path tiles_html =
  let buf = Buffer.create (String.length tiles_html + 256) in
  Buffer.add_string buf "<div class=\"board\" data-on:pointerdown=\"@post('";
  Buffer.add_string buf tap_path;
  Buffer.add_string buf "?id=' + evt.target.dataset.id)\">";
  Buffer.add_string buf tiles_html;
  Buffer.add_string buf "</div>";
  Buffer.contents buf
