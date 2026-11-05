defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.KiehlRoomExit do
  @moduledoc """
  The encounter exit returns visitors to Lighthalzen.

  ## Behavior

  - Resets the encounter when the room is empty before transferring the visitor.
  - Starts disabled and displays a summoning effect when enabled.

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
        y: 56,
        dir: 0,
        sprite: 45,
        name: "Kiehl_Room_Exit",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx =
      if getmapusers(ctx, "kh_kiehl02") < 1 do
        donpcevent(ctx, "KiehlRoom::OnReset")
      else
        ctx
      end

    warp(ctx, "lighthalzen", 193, 200)
  end

  def on_event("OnEnable", ctx), do: specialeffect(ctx, :summonslave)
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Kiehl_Room_Exit")
end
