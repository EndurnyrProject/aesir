defmodule Aesir.ZoneServer.Npc.Transpiler.CommandMap do
  @moduledoc """
  Data-driven registry of rAthena NPC buildins the transpiler maps onto the
  Aesir script DSL.

  The single extension point of the NPC codegen: implementing a new buildin is
  a DSL op plus a data edit here. Anything absent emits a raising stub —
  `todo(ctx, name, args)` in statement position, `Todo.call!(name, args)` in
  expression position.

  Dialog primitives (`mes`, `next`, `close`, `close2`, `close3`, `end`,
  `select`, `prompt`, `input`, `menu`) and the subroutine machinery
  (`callfunc`, `callsub`, `getarg`, `rand`, `getnpctimer`) are shaped directly
  by `Codegen`, not listed here.

  Buildin lookups (`command/1`, `call_read/1`, `supported?/1`) are
  case-insensitive, matching rAthena's script engine — the corpus spells
  `Initnpctimer`, `Monster` and friends freely.

  ## Command rules

  - `%{dsl: name, args: types}` — positional DSL call `name(ctx, a0, …)`;
    each type (`:int`, `:string`, `:item`, `:status`, `:emote`, `:effect`,
    `:equip_slot`, `:skill`) tells the codegen how to render/resolve the argument. A call
    with more arguments than declared types is truncated to the declared arity
    (trailing/optional buildin args, e.g. `emotion`'s target, are dropped).
  - `%{shape: :nullary, dsl: name}` — a no-argument effect (`nude`) → `name(ctx)`;
    any trailing rAthena arg (e.g. the optional char id) is dropped.
  - `%{shape: :heal, dsl: name}` — `heal <hp>,<sp>` → `name(ctx, hp: _, sp: _)`.
  - `%{shape: :warp}` — `warp "map",x,y` with `"Random"`/`"SavePoint"`
    special targets.
  - `%{shape: :ref1, dsl: name}` — a single-argument buildin (an event ref or
    an NPC name) → `name(ctx, arg)`; any other arg count stays a stub.
  - `%{shape: :timer, dsl: name}` — `initnpctimer`/`stopnpctimer`: zero args
    (self) → `name(ctx)`, one name arg → `name(ctx, arg)`; attach-flag
    variants stay a stub.
  - `%{shape: :opt1, dsl: name}` — an effect with one optional argument
    (`setcart {<type>}`, `enablenpc {"name"}`): zero args → `name(ctx)` (the
    DSL default/self form), one arg → `name(ctx, arg)`; any longer form stays
    a stub.
  - `%{shape: :item_group_optional, dsl: name, args: types}` — an item-group
    command/read with one optional trailing subgroup; omitted subgroups emit
    the runtime default `0`.
  - `%{shape: :riding, dsl: name}` — `setriding {<n>}` (rAthena mount/dismount):
    zero args → `name(ctx, true)`; one arg → `name(ctx, <n> != 0)` (a literal
    `0` dismounts, anything else mounts, matching rAthena); any longer form
    stays a stub.
  - `%{shape: :rentitem3}` — an extended rental grant: preserves its fixed
    refine/card attributes and folds three parallel option arrays into the
    DSL's `random_options` map; any other arity stays a stub.
  - `%{shape: :monster}` — `monster "map",x,y,"name",id,amount{,"event"...}`
    → `summon_mob(ctx, mob_id: _, map: _, at: _, ...)`; the display name and
    the size/ai tail are dropped.
  - `%{shape: :questinfo, dsl: name}` — `questinfo <Icon>{,<Mark Color>{,"<cond>"}}`
    (OnInit-only): the `QTYPE_*`/`QMARK_*` constants resolve to their client
    ints and a string-literal condition transpiles into a `(ctx -> boolean)`
    predicate closure; a dynamic condition, unknown constant, or unexpected
    arity stays a stub.
  - `%{shape: :announce, dsl: name, fixed: n}` — the broadcast buildins
    (`announce`/`mapannounce`/`areaannounce`/`broadcast`, plus `dispbottom`,
    the self-scoped chat-box message): keep the `n` fixed prefix args plus an
    optional trailing color; the rAthena font tail
    (fontType/fontSize/fontAlign/fontY) has no DSL equivalent and is dropped.
  - `%{shape: :setnpcdisplay}` — `setnpcdisplay`'s four arities, disambiguated
    by argument count and the second argument's type: `("<npc>", <sprite>)` is
    sprite-only, `("<npc>", "<display>")` name-only, the 3-arg form name +
    sprite, the 4-arg form adds size. A sprite name constant (`4_M_THIEF_RUMIN`)
    resolves via the `e_job_types` sprite table; an unknown constant or any
    other shape stays a stub.
  - `%{shape: :navigateto, dsl: name}` — `navigateto "<map>"{,<x>,<y>,<flag>,
    <hide_window>,<monster_id>}`: the map is required; the trailing args default
    to (0,0), `NAV_KAFRA_AND_AIRSHIP`, hidden, and no monster, matching rAthena.
    A `NAV_*` flag constant resolves to its service int, `hide_window` folds any
    nonzero to a boolean, and the optional `<char_id>` tail (target another
    character) is dropped.

  ## Reads

  `@reads` maps bare parameter names (`BaseLevel`, `Zeny`, …) to DSL read
  functions; `@call_reads` maps call-style reads (`countitem(id)`) the same
  way, plus one dedicated shape:

  - `%{shape: :nullary, dsl: name}` — a read with no supported arguments
    (`checkfalcon()`); any argument stays a stub.
  - `%{shape: :opt_read, dsl: name}` — a read with one optional integer
    argument (`is_party_leader({<party id>})`): zero args → `name(ctx)`, one
    arg → `name(ctx, arg)`; any longer form stays a stub.
  - `%{shape: :quest_check, dsl: name}` — `checkquest(id)` /
    `checkquest(id, HUNTING)` (and `questprogress`, the same core aliased):
    the default args-truncation rule (above) would silently drop the
    optional mode argument, so this shape keeps both the 1- and 2-arg forms.
    The mode constant (`HAVEQUEST`/`PLAYTIME`/`HUNTING`) resolves via the
    `:quest_mode` typed arg to `:havequest`/`:playtime`/`:hunting`.
  """

  @type rule :: map()

  @commands %{
    "getitem" => %{dsl: "give_item", args: [:item, :int]},
    "getgroupitem" => %{dsl: "get_group_item", args: [:item_group]},
    "getrandgroupitem" => %{
      shape: :item_group_optional,
      dsl: "get_rand_group_item",
      args: [:item_group, :int]
    },
    "getnameditem" => %{dsl: "get_named_item", args: [:item, :string]},
    "rentitem" => %{dsl: "give_item_rental", args: [:item, :int]},
    "rentitem3" => %{shape: :rentitem3},
    "getitembound" => %{dsl: "give_item_bound", args: [:item, :int, :bound]},
    "getitem2" => %{
      dsl: "getitem2",
      args: [:item, :int, :int, :int, :int, :item, :item, :item, :item]
    },
    "delitem" => %{dsl: "delitem", args: [:item, :int]},
    "delequip" => %{dsl: "delequip", args: [:equip_slot]},
    "successrefitem" => %{dsl: "successrefitem", args: [:equip_slot, :int]},
    "failedrefitem" => %{dsl: "failedrefitem", args: [:equip_slot]},
    "disable_items" => %{shape: :nullary, dsl: "disable_items"},
    "disableitemuse" => %{shape: :nullary, dsl: "disable_items"},
    "getexp" => %{dsl: "getexp", args: [:int, :int]},
    "heal" => %{shape: :heal, dsl: "heal"},
    "percentheal" => %{shape: :heal, dsl: "percent_heal"},
    "sc_start" => %{dsl: "sc_start", args: [:status, :int, :int]},
    "sc_end" => %{dsl: "sc_end", args: [:status]},
    "emotion" => %{dsl: "emotion", args: [:emote]},
    "specialeffect" => %{dsl: "specialeffect", args: [:effect]},
    "specialeffect2" => %{dsl: "specialeffect2", args: [:effect]},
    "cutin" => %{dsl: "cutin", args: [:string, :int]},
    "soundeffect" => %{dsl: "soundeffect", args: [:string, :int]},
    "progressbar" => %{dsl: "progressbar", args: [:string, :int]},
    "navigateto" => %{shape: :navigateto, dsl: "navigateto"},
    "consumeitem" => %{dsl: "consumeitem", args: [:item]},
    "nude" => %{shape: :nullary, dsl: "nude"},
    "viewpoint" => %{dsl: "viewpoint", args: [:int, :int, :int, :int, :int]},
    "killmonster" => %{dsl: "killmonster", args: [:string, :string]},
    "killmonsterall" => %{dsl: "killmonsterall", args: [:string]},
    "sleep2" => %{dsl: "sleep2", args: [:int]},
    "warp" => %{shape: :warp},
    "warpchar" => %{dsl: "warpchar", args: [:string, :int, :int, :int]},
    "areawarp" => %{
      dsl: "areawarp",
      args: [:string, :int, :int, :int, :int, :string, :int, :int, :int, :int]
    },
    "savepoint" => %{shape: :savepoint},
    "jobchange" => %{dsl: "jobchange", args: [:int]},
    "itemskill" => %{dsl: "itemskill", args: [:skill_opts]},
    "donpcevent" => %{shape: :ref1, dsl: "donpcevent"},
    "doevent" => %{shape: :ref1, dsl: "doevent"},
    "npctalk" => %{shape: :ref1, dsl: "npctalk"},
    "enablenpc" => %{shape: :opt1, dsl: "enablenpc"},
    "disablenpc" => %{shape: :opt1, dsl: "disablenpc"},
    "hideonnpc" => %{shape: :opt1, dsl: "hideonnpc"},
    "hideoffnpc" => %{shape: :opt1, dsl: "hideoffnpc"},
    "cloakonnpc" => %{shape: :opt1, dsl: "cloakonnpc"},
    "cloakonnpcself" => %{shape: :opt1, dsl: "cloakonnpc"},
    "cloakoffnpcself" => %{shape: :opt1, dsl: "cloakoffnpcself"},
    "initnpctimer" => %{shape: :timer, dsl: "initnpctimer"},
    "stopnpctimer" => %{shape: :timer, dsl: "stopnpctimer"},
    "monster" => %{shape: :monster},
    "announce" => %{shape: :announce, dsl: "announce", fixed: 2},
    "broadcast" => %{shape: :announce, dsl: "broadcast", fixed: 2},
    "mapannounce" => %{shape: :announce, dsl: "mapannounce", fixed: 3},
    "areaannounce" => %{shape: :announce, dsl: "areaannounce", fixed: 7},
    "dispbottom" => %{shape: :announce, dsl: "dispbottom", fixed: 1},
    "logmes" => %{dsl: "logmes", args: [:string]},
    "setcart" => %{shape: :opt1, dsl: "setcart"},
    "setfalcon" => %{shape: :riding, dsl: "setfalcon"},
    "setriding" => %{shape: :riding, dsl: "set_riding"},
    "openstorage" => %{shape: :nullary, dsl: "openstorage"},
    "setquest" => %{dsl: "setquest", args: [:int]},
    "erasequest" => %{dsl: "erasequest", args: [:int]},
    "completequest" => %{dsl: "completequest", args: [:int]},
    "changequest" => %{dsl: "changequest", args: [:int, :int]},
    "questinfo" => %{shape: :questinfo, dsl: "questinfo"},
    "repair" => %{dsl: "repair", args: [:int]},
    "repairall" => %{shape: :nullary, dsl: "repairall"},
    "skill" => %{dsl: "skill", args: [:skill, :int, :int]},
    "npcskill" => %{dsl: "npcskill", args: [:skill, :int, :int, :int]},
    "skilleffect" => %{dsl: "skilleffect", args: [:skill, :int]},
    "setlook" => %{dsl: "setlook", args: [:look, :int]},
    "setcell" => %{dsl: "setcell", args: [:string, :int, :int, :int, :int, :cell_type, :int]},
    "setnpcdisplay" => %{shape: :setnpcdisplay}
  }

  # Global rAthena functions (`callfunc "Name"`) mapped onto DSL primitives.
  # `:command` emits `dsl(ctx, args…)` in statement position; `:read` emits
  # `dsl(ctx)` in expression position.
  @functions %{
    "Job_Change" => %{kind: :command, dsl: "jobchange"},
    "F_CanChangeJob" => %{kind: :read, dsl: "can_change_job?"},
    "F_GetNumSuffix" => %{kind: :read, dsl: "num_suffix"},
    "F_InsertComma" => %{kind: :read, dsl: "insert_comma"},
    "F_getpositionname" => %{kind: :read, dsl: "equip_position_name"}
  }

  @warp_targets %{
    "Random" => ":random",
    "SavePoint" => ":save_point"
  }

  @reads %{
    "BaseClass" => "base_class",
    "BaseJob" => "base_job",
    "BaseLevel" => "base_level",
    "JobLevel" => "job_level",
    "Class" => "class",
    "Sex" => "sex",
    "Hp" => "hp",
    "MaxHp" => "max_hp",
    "Sp" => "sp",
    "MaxSp" => "max_sp",
    "Weight" => "weight",
    "Zeny" => "zeny"
  }

  @call_reads %{
    "countitem" => %{dsl: "count_item", args: [:item]},
    "groupranditem" => %{
      shape: :item_group_optional,
      dsl: "group_rand_item",
      args: [:item_group]
    },
    "isequipped" => %{dsl: "is_equipped", args: [:item]},
    "getequipid" => %{dsl: "getequipid", args: [:equip_slot]},
    "getequipcardid" => %{dsl: "getequipcardid", args: [:equip_slot, :int]},
    "getequipisequiped" => %{dsl: "getequipisequiped", args: [:equip_slot]},
    "getequiprefinerycnt" => %{dsl: "getequiprefinerycnt", args: [:equip_slot]},
    "getequipname" => %{dsl: "getequipname", args: [:equip_slot]},
    "getequipweaponlv" => %{dsl: "getequipweaponlv", args: [:equip_slot]},
    "getequiparmorlv" => %{dsl: "getequiparmorlv", args: [:equip_slot]},
    "getequipisenableref" => %{dsl: "getequipisenableref", args: [:equip_slot]},
    "getequippercentrefinery" => %{dsl: "getequippercentrefinery", args: [:equip_slot, :int]},
    "getequiprefinecost" => %{dsl: "getequiprefinecost", args: [:equip_slot, :int, :int]},
    "getiteminfo" => %{dsl: "getiteminfo", args: [:item, :int]},
    "strcharinfo" => %{dsl: "char_name", args: [:int]},
    "jobname" => %{dsl: "job_name", args: [:int]},
    "isbegin_quest" => %{dsl: "isbegin_quest", args: [:int]},
    "is_party_leader" => %{shape: :opt_read, dsl: "party_leader?"},
    "checkquest" => %{shape: :quest_check, dsl: "checkquest"},
    "questprogress" => %{shape: :quest_check, dsl: "questprogress"},
    "getpartnerid" => %{dsl: "getpartnerid", args: []},
    "gettimetick" => %{dsl: "gettimetick", args: [:int]},
    "checkre" => %{dsl: "checkre", args: [:int]},
    "vip_status" => %{dsl: "vip_status", args: [:int]},
    "checkfalcon" => %{shape: :nullary, dsl: "checkfalcon"},
    "checkcart" => %{dsl: "checkcart", args: []},
    "basicskillcheck" => %{dsl: "basicskillcheck", args: []},
    "getskilllv" => %{dsl: "getskilllv", args: [:skill]},
    "getcharid" => %{dsl: "getcharid", args: [:int]},
    "getlook" => %{dsl: "getlook", args: [:look]},
    "getmapusers" => %{dsl: "getmapusers", args: [:string]},
    "mobcount" => %{dsl: "mobcount", args: [:string, :string]},
    "getbrokenid" => %{dsl: "getbrokenid", args: [:int]},
    "eaclass" => %{dsl: "eaclass", args: [:int]},
    "roclass" => %{dsl: "roclass", args: [:int, :int]}
  }

  @spec command(String.t()) :: {:ok, rule()} | :error
  def command(name) when is_binary(name), do: Map.fetch(@commands, String.downcase(name))

  @spec read(String.t()) :: {:ok, String.t()} | :error
  def read(name) when is_binary(name), do: Map.fetch(@reads, name)

  @spec call_read(String.t()) :: {:ok, rule()} | :error
  def call_read(name) when is_binary(name), do: Map.fetch(@call_reads, String.downcase(name))

  @doc "A global `callfunc` name mapped onto a DSL primitive, or `:error`."
  @spec function(String.t()) :: {:ok, rule()} | :error
  def function(name) when is_binary(name), do: Map.fetch(@functions, name)

  @doc """
  Maps a `warp` string target (`"Random"`, `"SavePoint"`) to the one-arg DSL
  atom form. `:error` means a literal map name.
  """
  @spec warp_target(String.t()) :: {:ok, String.t()} | :error
  def warp_target(name) when is_binary(name), do: Map.fetch(@warp_targets, name)

  @doc """
  Every supported buildin name (commands + call reads + mapped global
  functions), for the analyzer.
  """
  @spec supported?(String.t()) :: boolean()
  def supported?(name) when is_binary(name) do
    key = String.downcase(name)

    Map.has_key?(@commands, key) or Map.has_key?(@call_reads, key) or
      match?({:ok, _}, function(name))
  end
end
