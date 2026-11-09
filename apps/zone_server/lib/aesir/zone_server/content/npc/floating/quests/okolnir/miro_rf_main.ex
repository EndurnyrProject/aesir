defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.MiroRfMain do
  @moduledoc """
  Runs the second Okolnir mirror challenge, spawning its wave and sealing its corridor.

  ## Behavior

  - On enable, spawns one wave mob on every wave point of the castle and marks the
    challenge corridors as blocked and not shootable.
  - On disable, removes the remaining wave mobs and reopens those corridors.
  - Ignores direct interaction and the death of its own wave mobs.

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
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_aru01"
      },
      %{
        map: "que_qaru02",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_aru02"
      },
      %{
        map: "que_qaru03",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_aru03"
      },
      %{
        map: "que_qaru04",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_aru04"
      },
      %{
        map: "que_qaru05",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_aru05"
      },
      %{
        map: "que_qsch01",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_sch01"
      },
      %{
        map: "que_qsch02",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_sch02"
      },
      %{
        map: "que_qsch03",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_sch03"
      },
      %{
        map: "que_qsch04",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_sch04"
      },
      %{
        map: "que_qsch05",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_rf_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @wave_points [
    57,
    301,
    57,
    299,
    48,
    291,
    48,
    289,
    68,
    290,
    70,
    290,
    72,
    295,
    72,
    293,
    90,
    296,
    92,
    296,
    56,
    282,
    58,
    282,
    66,
    283,
    66,
    281,
    80,
    284,
    82,
    284,
    44,
    273,
    46,
    273,
    50,
    273,
    52,
    273,
    54,
    269,
    54,
    267,
    66,
    271,
    66,
    270,
    81,
    273,
    81,
    272,
    88,
    276,
    90,
    276,
    94,
    276,
    96,
    276,
    64,
    258,
    66,
    258,
    76,
    263,
    76,
    261,
    87,
    265,
    87,
    263,
    50,
    252,
    52,
    252,
    76,
    252,
    78,
    252,
    99,
    255,
    99,
    253,
    53,
    245,
    53,
    243
  ]

  @corridor_rects [
    57,
    298,
    57,
    301,
    48,
    288,
    48,
    291,
    68,
    290,
    71,
    290,
    72,
    292,
    72,
    295,
    90,
    296,
    93,
    296,
    56,
    282,
    59,
    282,
    66,
    280,
    66,
    283,
    80,
    284,
    83,
    284,
    44,
    273,
    47,
    273,
    50,
    273,
    53,
    273,
    54,
    266,
    54,
    269,
    66,
    270,
    66,
    271,
    81,
    272,
    81,
    273,
    88,
    276,
    91,
    276,
    94,
    276,
    97,
    276,
    64,
    258,
    67,
    258,
    76,
    260,
    76,
    263,
    87,
    262,
    87,
    265,
    50,
    252,
    53,
    252,
    76,
    252,
    79,
    252,
    99,
    252,
    99,
    255,
    53,
    242,
    53,
    245
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    ctx
    |> summon_wave(castle)
    |> seal_corridors(castle, 0)
  end

  def on_event("OnDisable", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    ctx
    |> killmonster("que_q#{castle}", "#miro_rf_#{castle}::OnMyMobDead")
    |> seal_corridors(castle, 1)
  end

  def on_event("OnMyMobDead", ctx), do: ctx

  defp summon_wave(ctx, castle) do
    map = "que_q#{castle}"
    event = "#miro_rf_#{castle}::OnMyMobDead"

    Enum.reduce(Enum.chunk_every(@wave_points, 2), ctx, fn [x, y], ctx ->
      summon_mob(ctx, mob_id: 1935, map: map, at: {x, y}, event: event)
    end)
  end

  defp seal_corridors(ctx, castle, flag) do
    map = "que_q#{castle}"

    Enum.reduce(Enum.chunk_every(@corridor_rects, 4), ctx, fn [x1, y1, x2, y2], ctx ->
      ctx
      |> setcell(map, x1, y1, x2, y2, :walkable, flag)
      |> setcell(map, x1, y1, x2, y2, :shootable, flag)
    end)
  end
end
