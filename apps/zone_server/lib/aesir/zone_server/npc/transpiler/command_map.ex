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
    (`setcart {<type>}`): zero args → `name(ctx)` (the DSL default), one arg
    → `name(ctx, arg)`; any longer form stays a stub.
  - `%{shape: :monster}` — `monster "map",x,y,"name",id,amount{,"event"...}`
    → `summon_mob(ctx, mob_id: _, map: _, at: _, ...)`; the display name and
    the size/ai tail are dropped.
  - `%{shape: :announce, dsl: name, fixed: n}` — the broadcast buildins
    (`announce`/`mapannounce`/`areaannounce`/`broadcast`, plus `dispbottom`,
    the self-scoped chat-box message): keep the `n` fixed prefix args plus an
    optional trailing color; the rAthena font tail
    (fontType/fontSize/fontAlign/fontY) has no DSL equivalent and is dropped.

  ## Reads

  `@reads` maps bare parameter names (`BaseLevel`, `Zeny`, …) to DSL read
  functions; `@call_reads` maps call-style reads (`countitem(id)`) the same
  way, plus one dedicated shape:

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
    "delitem" => %{dsl: "delitem", args: [:item, :int]},
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
    "consumeitem" => %{dsl: "consumeitem", args: [:item]},
    "nude" => %{shape: :nullary, dsl: "nude"},
    "viewpoint" => %{dsl: "viewpoint", args: [:int, :int, :int, :int, :int]},
    "killmonster" => %{dsl: "killmonster", args: [:string, :string]},
    "warp" => %{shape: :warp},
    "savepoint" => %{shape: :savepoint},
    "jobchange" => %{dsl: "jobchange", args: [:int]},
    "itemskill" => %{dsl: "itemskill", args: [:skill_opts]},
    "donpcevent" => %{shape: :ref1, dsl: "donpcevent"},
    "doevent" => %{shape: :ref1, dsl: "doevent"},
    "npctalk" => %{shape: :ref1, dsl: "npctalk"},
    "enablenpc" => %{shape: :ref1, dsl: "enablenpc"},
    "disablenpc" => %{shape: :ref1, dsl: "disablenpc"},
    "hideonnpc" => %{shape: :ref1, dsl: "hideonnpc"},
    "hideoffnpc" => %{shape: :ref1, dsl: "hideoffnpc"},
    "initnpctimer" => %{shape: :timer, dsl: "initnpctimer"},
    "stopnpctimer" => %{shape: :timer, dsl: "stopnpctimer"},
    "monster" => %{shape: :monster},
    "announce" => %{shape: :announce, dsl: "announce", fixed: 2},
    "broadcast" => %{shape: :announce, dsl: "broadcast", fixed: 2},
    "mapannounce" => %{shape: :announce, dsl: "mapannounce", fixed: 3},
    "areaannounce" => %{shape: :announce, dsl: "areaannounce", fixed: 7},
    "dispbottom" => %{shape: :announce, dsl: "dispbottom", fixed: 1},
    "setcart" => %{shape: :opt1, dsl: "setcart"},
    "openstorage" => %{shape: :nullary, dsl: "openstorage"},
    "setquest" => %{dsl: "setquest", args: [:int]},
    "erasequest" => %{dsl: "erasequest", args: [:int]},
    "completequest" => %{dsl: "completequest", args: [:int]},
    "changequest" => %{dsl: "changequest", args: [:int, :int]}
  }

  # Global rAthena functions (`callfunc "Name"`) mapped onto DSL primitives.
  # `:command` emits `dsl(ctx, args…)` in statement position; `:read` emits
  # `dsl(ctx)` in expression position.
  @functions %{
    "Job_Change" => %{kind: :command, dsl: "jobchange"},
    "F_CanChangeJob" => %{kind: :read, dsl: "can_change_job?"},
    "F_GetNumSuffix" => %{kind: :read, dsl: "num_suffix"},
    "F_InsertComma" => %{kind: :read, dsl: "insert_comma"}
  }

  @warp_targets %{
    "Random" => ":random",
    "SavePoint" => ":save_point"
  }

  @reads %{
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
    "isequipped" => %{dsl: "is_equipped", args: [:item]},
    "getequipid" => %{dsl: "getequipid", args: [:equip_slot]},
    "strcharinfo" => %{dsl: "char_name", args: [:int]},
    "jobname" => %{dsl: "job_name", args: [:int]},
    "isbegin_quest" => %{dsl: "isbegin_quest", args: [:int]},
    "checkquest" => %{shape: :quest_check, dsl: "checkquest"},
    "questprogress" => %{shape: :quest_check, dsl: "questprogress"},
    "getpartnerid" => %{dsl: "getpartnerid", args: []},
    "gettimetick" => %{dsl: "gettimetick", args: [:int]},
    "checkre" => %{dsl: "checkre", args: [:int]},
    "vip_status" => %{dsl: "vip_status", args: [:int]},
    "checkcart" => %{dsl: "checkcart", args: []},
    "getskilllv" => %{dsl: "getskilllv", args: [:skill]},
    "getcharid" => %{dsl: "getcharid", args: [:int]}
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

  @doc "Every supported buildin name (commands + call reads), for the analyzer."
  @spec supported?(String.t()) :: boolean()
  def supported?(name) when is_binary(name) do
    key = String.downcase(name)
    Map.has_key?(@commands, key) or Map.has_key?(@call_reads, key)
  end
end
