defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Getitem22 do
  @moduledoc """
  Broken Sword blade piece hidden in the dungeon, revealed after its trace is found.

  ## Behavior

  - A player on Broken Sword step 8 who touches it finds a piece of the blade, advancing
    to step 9.
  - Hidden at startup; when its countdown reveals it, it stops that countdown and asks
    the floor controller to activate another trace.

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
        y: 201,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#getitem2-2",
        trigger: {2, 1}
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :b_sword, 0) == 8 do
      ctx
      |> set_char_var(:b_sword, 9)
      |> mes("You found a ^FF0000piece of blade^000000.")
      |> mes("Seems like it's a part of the sword you've been looking for.")
      |> close()
    else
      ctx
    end
  end

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "#getitem2-2")

  def on_event("OnCommandOn", ctx) do
    ctx
    |> enablenpc("#getitem2-2")
    |> donpcevent("timer2-2::OnCommandOff")
    |> donpcevent("start02#gnbs::OnCommandOn")
  end

  def on_event("OnCommandOff", ctx), do: disablenpc(ctx, "#getitem2-2")
end
