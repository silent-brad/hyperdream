let num_cols = 50
let num_rows = 50
let num_cells = num_cols * num_rows

let color_name = function
  | 0 -> "dead"
  | 1 -> "red"
  | 2 -> "blue"
  | 3 -> "green"
  | 4 -> "orange"
  | 5 -> "fuchsia"
  | 6 -> "purple"
  | _ -> "dead"

let random_board () =
  Array.init num_cells (fun _ ->
    if Random.int 100 < 30 then 1 + Random.int 6 else 0)

let wrap_idx i max = ((i mod max) + max) mod max

let count_neighbors board x y =
  let count = ref 0 in
  let neighbor_colors = Array.make 7 0 in
  for dy = -1 to 1 do
    for dx = -1 to 1 do
      if dx <> 0 || dy <> 0 then begin
        let nx = wrap_idx (x + dx) num_cols in
        let ny = wrap_idx (y + dy) num_rows in
        let c = board.(ny * num_cols + nx) in
        if c > 0 then begin
          incr count;
          neighbor_colors.(c) <- neighbor_colors.(c) + 1
        end
      end
    done
  done;
  (!count, neighbor_colors)

let pick_random_neighbor_color neighbor_colors =
  let live = ref [] in
  for c = 1 to 6 do
    for _ = 1 to neighbor_colors.(c) do
      live := c :: !live
    done
  done;
  match !live with
  | [] -> 1
  | l -> List.nth l (Random.int (List.length l))

let next_generation board =
  Array.init num_cells (fun i ->
    let x = i mod num_cols in
    let y = i / num_cols in
    let n, neighbor_colors = count_neighbors board x y in
    let cell = board.(i) in
    if cell > 0 then
      if n = 2 || n = 3 then cell else 0
    else
      if n = 3 then pick_random_neighbor_color neighbor_colors else 0)

let fill_cross board idx color =
  let x = idx mod num_cols in
  let y = idx / num_cols in
  let set dx dy =
    let nx = wrap_idx (x + dx) num_cols in
    let ny = wrap_idx (y + dy) num_rows in
    board.(ny * num_cols + nx) <- color
  in
  set 0 0;
  set (-1) 0;
  set 1 0;
  set 0 (-1);
  set 0 1
