defmodule Aesir.ZoneServer.Content.Npc.Quests.Okolnir.GdMainMobctrl do
  @moduledoc """
  Controls the Okolnir castle's Piamette encounter monsters.

  ## Behavior

  - Summons the encounter's monsters and replenishes Piamette's balls when few remain.
  - Removes remaining encounter monsters on reset.

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
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_main_mobctrl"
      },
      %{
        map: "que_qaru01",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_aru01_mobctrl"
      },
      %{
        map: "que_qaru02",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_aru02_mobctrl"
      },
      %{
        map: "que_qaru03",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_aru03_mobctrl"
      },
      %{
        map: "que_qaru04",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_aru04_mobctrl"
      },
      %{
        map: "que_qaru05",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_aru05_mobctrl"
      },
      %{
        map: "que_qsch01",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_sch01_mobctrl"
      },
      %{
        map: "que_qsch02",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_sch02_mobctrl"
      },
      %{
        map: "que_qsch03",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_sch03_mobctrl"
      },
      %{
        map: "que_qsch04",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_sch04_mobctrl"
      },
      %{
        map: "que_qsch05",
        x: 1,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gd_sch05_mobctrl"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  # One wave per encounter monster; the coordinates come in x/y pairs.
  @encounter_waves [
    {1738,
     [
       107,
       152,
       109,
       135,
       113,
       116,
       157,
       107,
       163,
       133,
       149,
       156,
       131,
       139,
       135,
       136,
       131,
       132,
       128,
       136,
       110,
       145,
       129,
       114,
       148,
       114,
       155,
       128,
       152,
       145,
       131,
       151,
       110,
       130
     ]},
    {1275,
     [
       130,
       139,
       135,
       137,
       130,
       132,
       128,
       137,
       109,
       145,
       109,
       130,
       128,
       114,
       147,
       114,
       154,
       128,
       151,
       145,
       130,
       151
     ]},
    {1390,
     [
       132,
       139,
       135,
       135,
       132,
       132,
       128,
       135,
       111,
       145,
       111,
       130,
       130,
       114,
       149,
       114,
       156,
       128,
       153,
       145,
       132,
       151
     ]},
    {1699,
     [
       133,
       139,
       135,
       134,
       133,
       132,
       128,
       135,
       112,
       145,
       131,
       114,
       150,
       114,
       157,
       128,
       154,
       145,
       133,
       151,
       112,
       130
     ]}
  ]

  # Reinforcements summoned once the wave thins out, as x/y pairs.
  @reinforcement_points [
    107,
    152,
    109,
    135,
    113,
    116,
    157,
    107,
    163,
    133,
    149,
    156
  ]

  @event_suffix "_mobctrl::OnMyMobDead"
  @reinforce_below 7

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    Enum.reduce(@encounter_waves, ctx, fn {mob_id, points}, ctx ->
      summon_points(ctx, castle, mob_id, points)
    end)
  end

  def on_event("OnReset", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    killmonster(ctx, castle_map(castle), event_label(castle))
  end

  def on_event("OnMyMobDead", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    if mobcount(ctx, castle_map(castle), event_label(castle)) < @reinforce_below do
      summon_points(ctx, castle, 1738, @reinforcement_points)
    else
      ctx
    end
  end

  defp summon_points(ctx, castle, mob_id, points) do
    Enum.reduce(Enum.chunk_every(points, 2), ctx, fn [x, y], ctx ->
      summon_mob(ctx,
        mob_id: mob_id,
        map: castle_map(castle),
        at: {x, y},
        event: event_label(castle)
      )
    end)
  end

  defp castle_map(castle), do: "que_q#{castle}"
  defp event_label(castle), do: "#gd_#{castle}" <> @event_suffix
end
