defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor1Warp do
  @moduledoc """
  The first door’s timed passage crosses the locked doorway.

  ## Behavior

  - Starts a thirty-second timer and resets the door when the passage expires.
  - Transfers visitors across the doorway on touch.

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
        x: 43,
        y: 33,
        dir: 0,
        sprite: 45,
        name: "Big_Door_1_Warp",
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

  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Big_Door_1_Warp")
  end

  def on_event("OnTimer30000", ctx) do
    ctx
    |> stopnpctimer()
    |> specialeffect(:summonslave)
    |> disablenpc("Big_Door_1_Warp")
    |> set_npc_var_of("KHDoor1Opened", "Big Door#BigDoorKHQ1", 0)
  end

  def on_event("OnTouch_", ctx) do
    warp(ctx, "kh_kiehl01", 55, 33)
  end
end
