defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MonsterMaster do
  @moduledoc """
  The hidden controller of the escaped-pet event in the expedition camp, which lets one of
  Breeder Taab's creatures loose every hour.

  ## Behavior

  - Starts its timer on two rolls out of three when enabled or clicked.
  - Every hour lets one of the three pets escape at its own spot, announces Taab's line and
    hides that pet.
  - After eleven hours, and when the escaped creature dies, announces the capture, reveals the
    three pets, clears the monsters and stops the timer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#monster_master"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @map "mid_camp"
  @mob_event "#monster_master::OnMyMobDead"
  @captured_message "Breeder Taab: I've captured an escaped creature safely. Sorry for yelling so loud."

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: maybe_start_timer(ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: maybe_start_timer(ctx)
  def on_event("OnStop", ctx), do: ctx |> killmonster(@map, @mob_event) |> stopnpctimer()

  def on_event("OnTimer3600000", ctx) do
    case Enum.random(1..3) do
      1 ->
        escaped(
          ctx,
          1986,
          {149, 291},
          "Tatacho#alba02",
          "Breeder Taab: Argh! My Tatacho ran away!"
        )

      2 ->
        escaped(
          ctx,
          1989,
          {154, 273},
          "Hillsrion#alba01",
          "Breeder Taab: Argh! My Hillsrion ran away!"
        )

      3 ->
        escaped(ctx, 1992, {184, 246}, "Cornus#alba03", "Breeder Taab: Argh! My Cornus ran away!")
    end
  end

  def on_event("OnTimer3960000", ctx) do
    ctx
    |> killmonster(@map, @mob_event)
    |> mapannounce(@map, @captured_message, 1, "0x00ff00")
    |> donpcevent("Hillsrion#alba01::OnEnable")
    |> donpcevent("Tatacho#alba02::OnEnable")
    |> donpcevent("Cornus#alba03::OnEnable")
    |> stopnpctimer()
  end

  def on_event("OnMyMobDead", ctx) do
    ctx
    |> mapannounce(@map, @captured_message, 1, "0x00ff00")
    |> donpcevent("Hillsrion#alba01::OnEnable")
    |> donpcevent("Tatacho#alba02::OnEnable")
    |> donpcevent("Cornus#alba03::OnEnable")
    |> killmonster(@map, @mob_event)
    |> stopnpctimer()
  end

  # The reference starts the timer on two out of three enabling rolls, and on a click.
  defp maybe_start_timer(ctx) do
    if Enum.random(1..3) > 1, do: initnpctimer(ctx), else: ctx
  end

  defp escaped(ctx, mob_id, at, pet, message) do
    ctx
    |> summon_mob(mob_id: mob_id, map: @map, at: at, event: @mob_event)
    |> mapannounce(@map, message, 1, "0x00ff00")
    |> donpcevent("#{pet}::OnDisable")
  end
end
