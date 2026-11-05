defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.KiehlRoomWarp do
  @moduledoc """
  This timed passage leads into Kiehl’s room.

  ## Behavior

  - Transfers players into Kiehl’s room when touched.
  - Runs its visual effect when enabled and disables itself after thirty seconds.

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
        map: "kh_mansion",
        x: 27,
        y: 27,
        dir: 0,
        sprite: 45,
        name: "Kiehl_Room_Warp",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    warp(ctx, "kh_kiehl01", 10, 31)
  end

  def on_event("OnEnable", ctx) do
    ctx |> initnpctimer() |> specialeffect(:summonslave)
  end

  def on_event("OnTimer30000", ctx) do
    ctx |> stopnpctimer() |> specialeffect(:summonslave) |> disablenpc("Kiehl_Room_Warp")
  end

  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Kiehl_Room_Warp")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)
end
