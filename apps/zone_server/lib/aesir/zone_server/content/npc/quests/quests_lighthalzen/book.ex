defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Book do
  @moduledoc """
  Benkaistein's journal can be found among the books.

  ## Behavior

  - Gives the journal to the player at the appropriate quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 168,
        y: 117,
        dir: 3,
        sprite: 111,
        name: "Book",
        scope: :shared,
        unique_name: "Book#lhz"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :friendship, 0) do
      11 ->
        ctx
        |> mes("^3355FFThere's nothing")
        |> mes("over here that you")
        |> mes("really need anymore.^000000")
        |> close()

      10 ->
        ctx
        |> set_char_var(:friendship, 11)
        |> give_item(7351, 1)
        |> mes("^3355FFThis book is labeled,")
        |> mes("''Benkaistein's Journal")
        |> mes("Vol. 6.'' This is probably")
        |> mes("what Benkaistein was trying")
        |> mes("to find, so it might be best to")
        |> mes("bring this and show it to him.^000000")
        |> close()

      _ ->
        ctx
        |> mes("^3355FFThere's nothing of")
        |> mes("any real interest")
        |> mes("over here for now.^000000")
        |> close()
    end
  end
end
