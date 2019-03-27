(** Global list of tables *)

open Printf
open ExtLib

type table = Sql.table
[@@deriving show {with_path=false}]

let all : table list ref = ref []

(** FIXME table names case sensitivity? *)
let by_name name = fun (n,_) -> n = name

(** @raise Error when no such table *)
let get_from tables name =
  try
    List.find (by_name name) tables
  with Not_found -> failwith (sprintf "no such table %s" name)

let get name = get_from !all name
let get_schema name = snd (get name)
let check name = ignore (get name)

let add v =
  let (name,_) = v in
  match List.find_all (by_name name) !all with
  | [] -> all := v :: !all
  | _ -> failwith (sprintf "table %s already exists" name)

let drop name = check name; all := List.remove_if (by_name name) !all

let alter name f =
  check name;
  let alter_scheme ((n,s) as table) =
    if n = name then
      name, f s
    else
      table
  in
  all := List.map alter_scheme !all

let alter_add name col pos = alter name (fun s -> Sql.Schema.add s col pos)
let alter_drop name col = alter name (fun s -> Sql.Schema.drop s col)
let alter_change name oldcol col pos = alter name (fun s -> Sql.Schema.change s oldcol col pos)

let print ch tables = let out = IO.output_channel ch in List.iter (Sql.print_table out) tables; IO.flush out
let print_all () = print stdout !all
let print1 name = print stdout [get name]

let reset () = all := []

