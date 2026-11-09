defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.ToAgitMainGate do
  @moduledoc """
  Returns players from Okolnir to their castle.

  ## Behavior

  - Warps players to the matching castle when they touch the gate.
  - Disables the gate on initialization.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - Toshiro90
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/okolnir.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_qaru01",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_aru01_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_aru02_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_aru03_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_aru04_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_aru05_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_sch01_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_sch02_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_sch03_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_sch04_gate",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 252,
        y: 339,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#to_agit_sch05_gate",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @arug_castles %{
    1 => {"arug_cas01", 157, 369},
    2 => {"arug_cas02", 349, 355},
    3 => {"arug_cas03", 321, 153},
    4 => {"arug_cas04", 321, 153},
    5 => {"arug_cas05", 321, 153}
  }

  @schg_castles %{
    1 => {"schg_cas01", 369, 306},
    2 => {"schg_cas02", 177, 355},
    3 => {"schg_cas03", 81, 95},
    4 => {"schg_cas04", 369, 306},
    5 => {"schg_cas05", 369, 306}
  }

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    queue_map = strnpcinfo(ctx, 4)
    castle = Rathena.atoi(Rathena.charat(queue_map, Rathena.getstrlen(queue_map) - 1))

    case destination(queue_map, castle) do
      {map, x, y} -> warp(ctx, map, x, y)
      nil -> ctx
    end
  end

  def on_event("OnInit", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", castle) |> disablenpc("#to_agit_#{castle}_gate")
  end

  # The last character of the queue map is the castle number: rAthena stores it in a variable
  # without `$`, which converts the character to its integer value.
  defp destination(queue_map, castle) do
    if Rathena.truthy?(Rathena.compare(queue_map, "aru")),
      do: Map.get(@arug_castles, castle),
      else: Map.get(@schg_castles, castle)
  end
end
