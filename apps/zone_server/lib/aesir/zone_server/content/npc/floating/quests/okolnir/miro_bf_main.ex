defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.MiroBfMain do
  @moduledoc """
  Runs the first Okolnir mirror challenge, spawning its wave and sealing its corridor.

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
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_aru01"
      },
      %{
        map: "que_qaru02",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_aru02"
      },
      %{
        map: "que_qaru03",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_aru03"
      },
      %{
        map: "que_qaru04",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_aru04"
      },
      %{
        map: "que_qaru05",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_aru05"
      },
      %{
        map: "que_qsch01",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_sch01"
      },
      %{
        map: "que_qsch02",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_sch02"
      },
      %{
        map: "que_qsch03",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_sch03"
      },
      %{
        map: "que_qsch04",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_sch04"
      },
      %{
        map: "que_qsch05",
        x: 2,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_bf_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @wave_points [
    44,
    270,
    46,
    270,
    50,
    287,
    52,
    287,
    50,
    265,
    52,
    265,
    56,
    279,
    58,
    279,
    64,
    301,
    64,
    298,
    62,
    272,
    64,
    272,
    58,
    245,
    58,
    243,
    72,
    289,
    72,
    287,
    68,
    257,
    68,
    255,
    73,
    263,
    73,
    261,
    75,
    251,
    75,
    249,
    79,
    283,
    79,
    281,
    82,
    271,
    84,
    271,
    89,
    295,
    89,
    293,
    88,
    276,
    90,
    276,
    88,
    266,
    90,
    266,
    94,
    256,
    96,
    256,
    64,
    301,
    64,
    299,
    100,
    251,
    102,
    251
  ]

  @corridor_rects [
    44,
    270,
    47,
    270,
    50,
    287,
    53,
    287,
    50,
    265,
    53,
    265,
    56,
    279,
    59,
    279,
    64,
    298,
    64,
    301,
    62,
    272,
    65,
    272,
    58,
    242,
    58,
    245,
    72,
    286,
    72,
    289,
    68,
    254,
    68,
    259,
    73,
    260,
    73,
    263,
    75,
    248,
    75,
    251,
    79,
    280,
    79,
    283,
    82,
    271,
    85,
    271,
    89,
    292,
    89,
    295,
    88,
    276,
    91,
    276,
    88,
    266,
    91,
    266,
    94,
    256,
    97,
    256,
    64,
    298,
    64,
    301,
    100,
    251,
    103,
    251
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
    |> killmonster("que_q#{castle}", "#miro_bf_#{castle}::OnMyMobDead")
    |> seal_corridors(castle, 1)
  end

  def on_event("OnMyMobDead", ctx), do: ctx

  defp summon_wave(ctx, castle) do
    map = "que_q#{castle}"
    event = "#miro_bf_#{castle}::OnMyMobDead"

    Enum.reduce(Enum.chunk_every(@wave_points, 2), ctx, fn [x, y], ctx ->
      summon_mob(ctx, mob_id: 1934, map: map, at: {x, y}, event: event)
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
