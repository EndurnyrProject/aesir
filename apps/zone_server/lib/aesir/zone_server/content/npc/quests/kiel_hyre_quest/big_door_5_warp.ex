defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor5Warp do
  @moduledoc """
  The final door’s timed passage leads toward Kiehl’s room.

  ## Behavior

  - Enables a thirty-second timer and resets the door when the passage expires.
  - Transfers qualified visitors onward and returns others to the corridor.

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
        x: 166,
        y: 186,
        dir: 0,
        sprite: 45,
        name: "Big_Door_5_Warp",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    ctx |> initnpctimer() |> specialeffect(:summonslave)
  end

  def on_event("OnTimer30000", ctx) do
    ctx
    |> stopnpctimer()
    |> specialeffect(:summonslave)
    |> disablenpc("Big_Door_5_Warp")
    |> set_npc_var_of("KHDoor5Opened", "Big Door#BigDoorKHQ5", 0)
  end

  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Big_Door_5_Warp")
  end

  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) >= 46 do
      warp(ctx, "kh_kiehl02", 50, 7)
    else
      warp(ctx, "kh_kiehl01", 166, 183)
    end
  end
end
