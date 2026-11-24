defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Trace35 do
  @moduledoc """
  Trace of a Broken Sword blade piece, active for a limited time in the dungeon.

  ## Behavior

  - Hidden at startup until the floor controller activates it.
  - A player on Broken Sword step 9 who steps on it starts the countdown that reveals
    the blade piece next to it.
  - Hides itself 190 seconds after activation and asks the floor controller to activate
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
        map: "gon_dun03",
        x: 169,
        y: 90,
        dir: 0,
        sprite: 139,
        name: "trace3-5",
        scope: :shared,
        unique_name: "trace3-5#gnbs",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :b_sword, 0) == 9 do
      donpcevent(ctx, "timer3-5::OnCommandOn")
    else
      ctx
    end
  end

  @impl true
  def on_event("OnInit", ctx) do
    ctx |> initnpctimer() |> stopnpctimer() |> disablenpc("trace3-5#gnbs")
  end

  def on_event("OnCommandOn", ctx) do
    ctx |> enablenpc("trace3-5#gnbs") |> setnpctimer(0) |> startnpctimer()
  end

  def on_event("OnTimer190000", ctx) do
    ctx
    |> stopnpctimer()
    |> disablenpc("trace3-5#gnbs")
    |> donpcevent("start03#gnbs::OnCommandOn")
  end
end
