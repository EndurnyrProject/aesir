defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.KiehlRoomTrap do
  @moduledoc """
  The room trap summons guardians and manages encounter reset timers.

  ## Behavior

  - Marks the room busy and summons six guardians the first time the trap is touched.
  - Checks for an empty room at five, ten, and fifteen minutes, and resets unconditionally at
    twenty minutes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_kiehl02",
        x: 49,
        y: 10,
        dir: 0,
        sprite: -1,
        name: "Kiehl_Room_Trap",
        scope: :shared,
        trigger: {5, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if get_npc_var(ctx, "KHTrapSprung", 0) < 1 do
      ctx
      |> set_npc_var("KHTrapSprung", 1)
      |> set_server_temp_var("KHQuestBusy", 1)
      |> initnpctimer()
      |> summon_mob(mob_id: 1740, map: "kh_kiehl02", at: {47, 13})
      |> summon_mob(mob_id: 1739, map: "kh_kiehl02", at: {45, 13})
      |> summon_mob(mob_id: 1745, map: "kh_kiehl02", at: {49, 13})
      |> summon_mob(mob_id: 1740, map: "kh_kiehl02", at: {51, 13})
      |> summon_mob(mob_id: 1739, map: "kh_kiehl02", at: {53, 13})
      |> summon_mob(mob_id: 1745, map: "kh_kiehl02", at: {49, 13})
    else
      ctx
    end
  end

  def on_event("OnTimer300000", ctx), do: reset_if_empty(ctx)
  def on_event("OnTimer600000", ctx), do: reset_if_empty(ctx)
  def on_event("OnTimer900000", ctx), do: reset_if_empty(ctx)
  def on_event("OnTimer1200000", ctx), do: reset_room(ctx)
  def on_event("OnGlobalTimerOff", ctx), do: stopnpctimer(ctx)

  defp reset_if_empty(ctx) do
    if getmapusers(ctx, "kh_kiehl02") == 0, do: reset_room(ctx), else: ctx
  end

  defp reset_room(ctx) do
    ctx |> donpcevent("KiehlRoom::OnReset") |> stopnpctimer()
  end
end
