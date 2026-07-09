defmodule Aesir.ZoneServer.Npc.Transpiler.CommandMap do
  @moduledoc """
  Data-driven registry of rAthena NPC buildins the transpiler maps onto the
  Aesir script DSL.

  The single extension point of the NPC codegen: implementing a new buildin is
  a DSL op plus a data edit here. Anything absent emits a raising stub —
  `todo(ctx, name, args)` in statement position, `Todo.call!(name, args)` in
  expression position.

  Dialog primitives (`mes`, `next`, `close`, `close2`, `end`, `select`,
  `prompt`, `input`, `menu`) and the subroutine machinery (`callfunc`,
  `callsub`, `getarg`, `rand`, `getnpctimer`) are shaped directly by
  `Codegen`, not listed here.

  ## Command rules

  - `%{dsl: name, args: types}` — positional DSL call `name(ctx, a0, …)`;
    each type (`:int`, `:string`, `:item`, `:status`) tells the codegen how
    to render/resolve the argument.
  - `%{shape: :heal, dsl: name}` — `heal <hp>,<sp>` → `name(ctx, hp: _, sp: _)`.
  - `%{shape: :warp}` — `warp "map",x,y` with `"Random"`/`"SavePoint"`
    special targets.
  - `%{shape: :ref1, dsl: name}` — a single-argument buildin (an event ref or
    an NPC name) → `name(ctx, arg)`; any other arg count stays a stub.
  - `%{shape: :timer, dsl: name}` — `initnpctimer`/`stopnpctimer`: zero args
    (self) → `name(ctx)`, one name arg → `name(ctx, arg)`; attach-flag
    variants stay a stub.

  ## Reads

  `@reads` maps bare parameter names (`BaseLevel`, `Zeny`, …) to DSL read
  functions; `@call_reads` maps call-style reads (`countitem(id)`) the same
  way.
  """

  @type rule :: map()

  @commands %{
    "getitem" => %{dsl: "give_item", args: [:item, :int]},
    "delitem" => %{dsl: "delitem", args: [:item, :int]},
    "heal" => %{shape: :heal, dsl: "heal"},
    "percentheal" => %{shape: :heal, dsl: "percent_heal"},
    "sc_start" => %{dsl: "sc_start", args: [:status, :int, :int]},
    "sc_end" => %{dsl: "sc_end", args: [:status]},
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
    "stopnpctimer" => %{shape: :timer, dsl: "stopnpctimer"}
  }

  # Global rAthena functions (`callfunc "Name"`) mapped onto DSL primitives.
  # `:command` emits `dsl(ctx, args…)` in statement position; `:read` emits
  # `dsl(ctx)` in expression position.
  @functions %{
    "Job_Change" => %{kind: :command, dsl: "jobchange"},
    "F_CanChangeJob" => %{kind: :read, dsl: "can_change_job?"}
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
    "strcharinfo" => %{dsl: "char_name", args: [:int]},
    "jobname" => %{dsl: "job_name", args: [:int]}
  }

  @spec command(String.t()) :: {:ok, rule()} | :error
  def command(name) when is_binary(name), do: Map.fetch(@commands, name)

  @spec read(String.t()) :: {:ok, String.t()} | :error
  def read(name) when is_binary(name), do: Map.fetch(@reads, name)

  @spec call_read(String.t()) :: {:ok, rule()} | :error
  def call_read(name) when is_binary(name), do: Map.fetch(@call_reads, name)

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
  def supported?(name),
    do: Map.has_key?(@commands, name) or Map.has_key?(@call_reads, name)
end
