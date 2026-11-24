defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.BbqBoy do
  @moduledoc """
  Rinta speculates about the village chief’s visitors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 221,
        y: 310,
        dir: 4,
        sprite: 86,
        name: "BBQ Boy",
        scope: :shared,
        unique_name: "BBQ Boy#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Rinta]")
    |> mes("I didn't mean to,")
    |> mes("but I accidentally")
    |> mes("eavesdropped on those")
    |> mes("people over there. Are")
    |> mes("they really old friends")
    |> mes("with our Village Chief?")
    |> next()
    |> mes("[Rinta]")
    |> mes("In that case, they must")
    |> mes("be getting the special")
    |> mes("treatment usually reserved")
    |> mes("for visiting dignitaries and")
    |> mes("the like. Or something like that.")
    |> close()
  end
end
