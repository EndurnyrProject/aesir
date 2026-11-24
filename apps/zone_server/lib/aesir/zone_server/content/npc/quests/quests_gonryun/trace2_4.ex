defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Trace24 do
  @moduledoc """
  Trace of a Broken Sword blade piece, active for a limited time in the dungeon.

  ## Behavior

  - Hidden at startup until the floor controller activates it.
  - A player on Broken Sword step 8 who steps on it starts the countdown that reveals
    the blade piece next to it.
  - Hides itself 230 seconds after activation and asks the floor controller to activate
    another trace.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_dun02",
        x: 149,
        y: 74,
        dir: 0,
        sprite: 139,
        name: "trace2-4",
        scope: :shared,
        unique_name: "trace2-4#gnbs",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :b_sword, 0) == 8 do
      donpcevent(ctx, "timer2-4::OnCommandOn")
    else
      ctx
    end
  end

  @impl true
  def on_event("OnInit", ctx) do
    ctx |> initnpctimer() |> stopnpctimer() |> disablenpc("trace2-4#gnbs")
  end

  def on_event("OnCommandOn", ctx) do
    ctx |> enablenpc("trace2-4#gnbs") |> setnpctimer(0) |> startnpctimer()
  end

  def on_event("OnTimer230000", ctx) do
    ctx
    |> stopnpctimer()
    |> disablenpc("trace2-4#gnbs")
    |> donpcevent("start02#gnbs::OnCommandOn")
  end
end
