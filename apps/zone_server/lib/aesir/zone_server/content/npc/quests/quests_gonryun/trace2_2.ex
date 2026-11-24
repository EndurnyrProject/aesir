defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Trace22 do
  @moduledoc """
  Trace of a Broken Sword blade piece, active for a limited time in the dungeon.

  ## Behavior

  - Hidden at startup until the floor controller activates it.
  - A player on Broken Sword step 8 who steps on it starts the countdown that reveals
    the blade piece next to it.
  - Hides itself 130 seconds after activation and asks the floor controller to activate
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
        x: 265,
        y: 200,
        dir: 0,
        sprite: 139,
        name: "trace2-2",
        scope: :shared,
        unique_name: "trace2-2#gnbs",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :b_sword, 0) == 8 do
      donpcevent(ctx, "timer2-2::OnCommandOn")
    else
      ctx
    end
  end

  @impl true
  def on_event("OnInit", ctx) do
    ctx |> initnpctimer() |> stopnpctimer() |> disablenpc("trace2-2#gnbs")
  end

  def on_event("OnCommandOn", ctx) do
    ctx |> enablenpc("trace2-2#gnbs") |> setnpctimer(0) |> startnpctimer()
  end

  def on_event("OnTimer130000", ctx) do
    ctx
    |> stopnpctimer()
    |> disablenpc("trace2-2#gnbs")
    |> donpcevent("start02#gnbs::OnCommandOn")
  end
end
