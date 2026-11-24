defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Fabio do
  @moduledoc """
  Fabio talks about the ghost story and teases Mariana.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 181,
        y: 250,
        dir: 5,
        sprite: 706,
        name: "Fabio",
        scope: :shared,
        unique_name: "Fabio#bra"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_ghost, 0) do
      0 ->
        doevent(ctx, "Pedro#bra::OnTalk")

      1 ->
        ctx
        |> mes("[Fabio]")
        |> mes("You still wasting your time with that ghost story?")
        |> close()

      _ ->
        ctx
        |> mes("[Fabio]")
        |> mes("Mariana, wanna see something cool?")
        |> next()
        |> mes("[Mariana]")
        |> mes("kkkkkkkaaaaaacck!! Bugs!! Get 'em away!")
        |> close()
    end
  end
end
