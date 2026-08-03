defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.CommandSet do
  @moduledoc """
  Data-driven registry of the rAthena commands and reads the transpiler supports.

  This is the single extension point of the codegen stage: adding a new supported
  command is a data edit to `@commands`, and a new engine read is a data edit to
  `@reads` — no new control flow in `Codegen` unless the command needs a genuinely
  new emit *shape*.

  ## Command rules

  Each entry maps a verbatim rAthena command name to an emit rule:

  - `%{shape: :call, dsl: name, args: types}` — a positional DSL call
    `name(ctx, a0, a1, …)` where each `types` entry says how to render the
    matching positional argument (`:int` literal, `:string` literal, `:status`,
    `:item`, `:skill`, `:effect` resolver lookups).
  - `%{shape: :heal, dsl: name}` — the `itemheal`/`heal`/`percentheal` shape:
    `name(ctx, hp: …, sp: …)`, zero amounts omitted, `rand` rendered as a range.
  - `%{shape: :itemskill, dsl: name}` — `itemskill(ctx, skill, level: lv)`.
  - `%{shape: :announce, dsl: name, fixed: n}` — the broadcast buildins
    (`announce`/`mapannounce`/`areaannounce`/`broadcast`): keep the `n` fixed
    prefix args (the flag is the last one, rendered via the `:flag` arg type)
    plus an optional trailing color; the rAthena font tail
    (fontType/fontSize/fontAlign/fontY) has no DSL equivalent and is dropped.

  ## Reads

  `@reads` maps a rAthena read identifier (`BaseLevel`, `Zeny`, …) to the Aesir
  DSL read function emitted as `fn(ctx)`.
  """

  @type rule ::
          %{shape: :call, dsl: String.t(), args: [atom()]}
          | %{shape: :heal, dsl: String.t()}
          | %{shape: :itemskill, dsl: String.t()}
          | %{shape: :announce, dsl: String.t(), fixed: pos_integer()}

  @commands %{
    "homevolution" => %{shape: :call, dsl: "homevolution", args: []},
    "itemheal" => %{shape: :heal, dsl: "heal"},
    "heal" => %{shape: :heal, dsl: "heal"},
    "percentheal" => %{shape: :heal, dsl: "percent_heal"},
    "sc_start" => %{shape: :call, dsl: "sc_start", args: [:status, :int, :int]},
    "sc_end" => %{shape: :call, dsl: "sc_end", args: [:status]},
    "getitem" => %{shape: :call, dsl: "give_item", args: [:item, :int]},
    "delitem" => %{shape: :call, dsl: "delitem", args: [:item, :int]},
    "warp" => %{shape: :call, dsl: "warp", args: [:string, :int, :int]},
    "itemskill" => %{shape: :itemskill, dsl: "itemskill"},
    "specialeffect2" => %{shape: :call, dsl: "specialeffect2", args: [:effect]},
    "announce" => %{shape: :announce, dsl: "announce", fixed: 2},
    "broadcast" => %{shape: :announce, dsl: "broadcast", fixed: 2},
    "mapannounce" => %{shape: :announce, dsl: "mapannounce", fixed: 3},
    "areaannounce" => %{shape: :announce, dsl: "areaannounce", fixed: 7}
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

  @spec command(String.t()) :: {:ok, rule()} | :error
  def command(name) when is_binary(name), do: Map.fetch(@commands, name)

  @doc """
  Maps a `warp` first-argument string-target (`"Random"`, `"SavePoint"`) to the
  one-arg DSL atom form (`:random`, `:save_point`). Returns `:error` for literal
  map names, which fall through to the standard `warp "map",x,y` codegen.
  """
  @spec warp_target(String.t()) :: {:ok, String.t()} | :error
  def warp_target(name) when is_binary(name), do: Map.fetch(@warp_targets, name)

  @spec read(String.t()) :: {:ok, String.t()} | :error
  def read(name) when is_binary(name), do: Map.fetch(@reads, name)
end
