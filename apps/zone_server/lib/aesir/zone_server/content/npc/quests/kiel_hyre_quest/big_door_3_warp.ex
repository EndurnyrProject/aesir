defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor3Warp do
  @moduledoc """
  This timed passage transfers players beyond the third big door.

  ## Behavior

  - Runs its visual effect and timer when enabled, then disables itself after thirty seconds.
  - Resets the third door’s open flag on expiry and chooses the destination by quest progress.

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
        map: "kh_kiehl01",
        x: 78,
        y: 107,
        dir: 0,
        sprite: 45,
        name: "Big_Door_3_Warp",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    ctx |> initnpctimer() |> specialeffect(:summonslave)
  end

  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Big_Door_3_Warp")
  end

  def on_event("OnTimer30000", ctx) do
    ctx
    |> stopnpctimer()
    |> specialeffect(:summonslave)
    |> disablenpc("Big_Door_3_Warp")
    |> set_npc_var_of("KHDoor3Opened", "Big Door#BigDoorKHQ3", 0)
  end

  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) == 49 do
      warp(ctx, "kh_kiehl01", 82, 108)
    else
      warp(ctx, "kh_kiehl01", 68, 108)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
