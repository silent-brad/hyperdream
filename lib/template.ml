open Jingoo

let render_string template_str ~models =
  let jingoo_models = List.map (fun (k, v) -> (k, Jg_types.Tstr v)) models in
  Jg_template.from_string template_str ~models:jingoo_models

let render_file template_path ~models =
  let jingoo_models = List.map (fun (k, v) -> (k, Jg_types.Tstr v)) models in
  Jg_template.from_file template_path ~models:jingoo_models

let render_with_raw template_str ~models =
  let jingoo_models =
    List.map (fun (k, v) -> (k, Jg_types.Tsafe v)) models
  in
  Jg_template.from_string template_str ~models:jingoo_models

let render_mixed template_str ~str_models ~safe_models =
  let models =
    List.map (fun (k, v) -> (k, Jg_types.Tstr v)) str_models
    @ List.map (fun (k, v) -> (k, Jg_types.Tsafe v)) safe_models
  in
  Jg_template.from_string template_str ~models
