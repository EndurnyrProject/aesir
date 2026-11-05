defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor2Warp do
  @moduledoc """
  The second big door passage transports adventurers while its timed opening is active.

  ## Behavior

  - Starts an opening effect and disables the passage after thirty seconds, resetting the door flag.
  - Chooses the destination according to the adventurer’s quest stage.

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
        x: 173,
        y: 39,
        dir: 0,
        sprite: 45,
        name: "Big_Door_2_Warp",
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
    disablenpc(ctx, "Big_Door_2_Warp")
  end

  def on_event("OnTimer30000", ctx) do
    ctx
    |> stopnpctimer()
    |> specialeffect(:summonslave)
    |> disablenpc("Big_Door_2_Warp")
    |> set_npc_var_of("KHDoor2Opened", "Big Door#BigDoorKHQ2", 0)
  end

  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) == 48 do
      warp(ctx, "kh_kiehl01", 173, 35)
    else
      warp(ctx, "kh_kiehl01", 173, 52)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnEnable", ctx)
end
