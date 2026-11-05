defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor4Warp do
  @moduledoc """
  The fourth door’s temporary passage routes visitors according to quest progress.

  ## Behavior

  - Starts a thirty-second opening timer and disables the passage when it expires.
  - Clears the linked door’s open flag on expiry and routes touching players to the appropriate
    side.

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
        x: 41,
        y: 178,
        dir: 0,
        sprite: 45,
        name: "Big_Door_4_Warp",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnEnable", ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    ctx |> initnpctimer() |> specialeffect(:summonslave)
  end

  def on_event("OnInit", ctx), do: disablenpc(ctx, "Big_Door_4_Warp")

  def on_event("OnTimer30000", ctx) do
    ctx
    |> stopnpctimer()
    |> specialeffect(:summonslave)
    |> disablenpc("Big_Door_4_Warp")
    |> set_npc_var_of("KHDoor4Opened", "Big Door#BigDoorKHQ4", 0)
  end

  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) == 50 do
      warp(ctx, "kh_kiehl01", 38, 178)
    else
      warp(ctx, "kh_kiehl01", 47, 171)
    end
  end
end
