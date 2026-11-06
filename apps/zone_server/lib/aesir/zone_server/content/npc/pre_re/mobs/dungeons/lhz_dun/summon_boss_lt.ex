defmodule Aesir.ZoneServer.Content.Npc.PreRe.Mobs.Dungeons.LhzDun.SummonBossLt do
  @moduledoc """
  Timer driven summoner that spawns the random Biolabs MVP and its 99 minion in Lighthalzen Dungeon 3.

  ## Behavior

  - Arms its npc timer on init; six hourly checkpoints each roll one number out of six, and only the
    matching checkpoint summons. The seventh checkpoint always summons and stops the timer.
  - A summon places one random MVP (1646-1651) at one of six spots and one random 99 minion
    (1640-1645) at another of six spots, each with its own death event attached.
  - When the MVP dies it kills the minion through the minion's death event and re-arms the timer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - The Prometheus Project, rAthena Dev Team
    - Playtester
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/mobs/dungeons/lhz_dun.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "lhz_dun03",
        x: 2,
        y: 2,
        dir: 0,
        sprite: -1,
        name: "summon_boss_lt",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @map "lhz_dun03"
  @summon_event "summon_boss_lt::OnSummon"
  @mvp_death_event "summon_boss_lt::OnLhzMvPDead"
  @minion_death_event "summon_boss_lt::OnMy99Dead"
  @mvp_spots [{140, 232}, {75, 138}, {140, 87}, {205, 140}, {123, 137}, {175, 137}]
  @minion_spots [{183, 97}, {97, 96}, {47, 139}, {231, 140}, {139, 211}, {139, 259}]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer6000000", ctx), do: summon_if_rolled(ctx, 1)
  def on_event("OnTimer6300000", ctx), do: summon_if_rolled(ctx, 2)
  def on_event("OnTimer6600000", ctx), do: summon_if_rolled(ctx, 3)
  def on_event("OnTimer6900000", ctx), do: summon_if_rolled(ctx, 4)
  def on_event("OnTimer7200000", ctx), do: summon_if_rolled(ctx, 5)
  def on_event("OnTimer7500000", ctx), do: summon_if_rolled(ctx, 6)
  def on_event("OnTimer7800000", ctx), do: summon(ctx)
  def on_event("OnSummon", ctx), do: summon_pair(ctx)
  def on_event("OnLhzMvPDead", ctx), do: await_next_summon(ctx)
  def on_event("OnMy99Dead", ctx), do: ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: initnpctimer(ctx)

  defp summon_if_rolled(ctx, expected) do
    if Enum.random(1..6) == expected, do: summon(ctx), else: ctx
  end

  defp summon(ctx) do
    ctx
    |> donpcevent(@summon_event)
    |> stopnpctimer()
  end

  defp summon_pair(ctx) do
    {x, y} = Enum.at(@mvp_spots, Enum.random(1..6) - 1)

    ctx =
      summon_mob(ctx,
        mob_id: Enum.random(1646..1651),
        map: @map,
        at: {x, y},
        event: @mvp_death_event
      )

    {x, y} = Enum.at(@minion_spots, Enum.random(1..6) - 1)

    summon_mob(ctx,
      mob_id: Enum.random(1640..1645),
      map: @map,
      at: {x, y},
      event: @minion_death_event
    )
  end

  defp await_next_summon(ctx) do
    ctx
    |> killmonster(@map, @minion_death_event)
    |> initnpctimer()
  end
end
