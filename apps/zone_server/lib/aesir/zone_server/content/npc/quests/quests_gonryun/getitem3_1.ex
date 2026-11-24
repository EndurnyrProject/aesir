defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Getitem31 do
  @moduledoc """
  Broken Sword blade piece hidden in the dungeon, revealed after its trace is found.

  ## Behavior

  - A player on Broken Sword step 9 who touches it finds the last piece of the blade
    and assembles it, advancing to step 10.
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
        map: "gon_dun03",
        x: 10,
        y: 74,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#getitem3-1",
        trigger: {2, 1}
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :b_sword, 0) == 9 do
      ctx
      |> set_char_var(:b_sword, 10)
      |> mes("You found a ^FF0000piece of blade^000000.")
      |> mes("Seems like it's a part of the sword you've been looking for.")
      |> next()
      |> mes("You put all the pieces on the")
      |> mes("ground and assembled them.")
      |> mes("It looks like you've found all of the pieces of the blade.")
      |> close()
    else
      ctx
    end
  end

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "#getitem3-1")

  def on_event("OnCommandOn", ctx) do
    ctx
    |> enablenpc("#getitem3-1")
    |> donpcevent("timer3-1::OnCommandOff")
    |> donpcevent("start03#gnbs::OnCommandOn")
  end

  def on_event("OnCommandOff", ctx), do: disablenpc(ctx, "#getitem3-1")
end
