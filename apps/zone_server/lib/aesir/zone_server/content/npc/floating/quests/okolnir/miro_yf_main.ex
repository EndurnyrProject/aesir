defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.MiroYfMain do
  @moduledoc """
  Runs the third Okolnir mirror challenge, spawning its wave and sealing its corridor.

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
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_aru01"
      },
      %{
        map: "que_qaru02",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_aru02"
      },
      %{
        map: "que_qaru03",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_aru03"
      },
      %{
        map: "que_qaru04",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_aru04"
      },
      %{
        map: "que_qaru05",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_aru05"
      },
      %{
        map: "que_qsch01",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_sch01"
      },
      %{
        map: "que_qsch02",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_sch02"
      },
      %{
        map: "que_qsch03",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_sch03"
      },
      %{
        map: "que_qsch04",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_sch04"
      },
      %{
        map: "que_qsch05",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#miro_yf_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @wave_points [
    44,
    292,
    46,
    292,
    67,
    295,
    67,
    293,
    94,
    301,
    94,
    299,
    79,
    289,
    79,
    287,
    56,
    282,
    58,
    282,
    71,
    283,
    71,
    281,
    100,
    281,
    102,
    281,
    44,
    261,
    46,
    261,
    50,
    265,
    52,
    265,
    56,
    270,
    58,
    270,
    72,
    278,
    73,
    278,
    82,
    266,
    84,
    266,
    88,
    266,
    90,
    266,
    94,
    271,
    96,
    271,
    60,
    257,
    60,
    255,
    73,
    263,
    73,
    261,
    75,
    257,
    75,
    255,
    87,
    257,
    87,
    255,
    58,
    251,
    58,
    249,
    80,
    251,
    80,
    249,
    53,
    245,
    53,
    243,
    75,
    245,
    75,
    243,
    100,
    251,
    102,
    251,
    100,
    256,
    102,
    256
  ]

  @corridor_rects [
    44,
    292,
    47,
    292,
    67,
    292,
    67,
    295,
    94,
    298,
    94,
    301,
    79,
    286,
    79,
    289,
    56,
    282,
    59,
    282,
    71,
    280,
    71,
    283,
    100,
    281,
    103,
    281,
    44,
    261,
    47,
    261,
    50,
    265,
    53,
    265,
    56,
    270,
    59,
    270,
    72,
    278,
    73,
    278,
    82,
    266,
    85,
    266,
    88,
    266,
    91,
    266,
    94,
    271,
    97,
    271,
    60,
    254,
    60,
    257,
    73,
    260,
    73,
    263,
    75,
    254,
    75,
    257,
    87,
    254,
    87,
    257,
    58,
    248,
    58,
    251,
    80,
    248,
    80,
    251,
    53,
    242,
    53,
    245,
    75,
    242,
    75,
    245,
    100,
    251,
    103,
    251,
    100,
    256,
    103,
    256
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
    |> killmonster("que_q#{castle}", "#miro_yf_#{castle}::OnMyMobDead")
    |> seal_corridors(castle, 1)
  end

  def on_event("OnMyMobDead", ctx), do: ctx

  defp summon_wave(ctx, castle) do
    map = "que_q#{castle}"
    event = "#miro_yf_#{castle}::OnMyMobDead"

    Enum.reduce(Enum.chunk_every(@wave_points, 2), ctx, fn [x, y], ctx ->
      summon_mob(ctx, mob_id: 1936, map: map, at: {x, y}, event: event)
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
