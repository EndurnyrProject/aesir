defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.AmbitiousHollgrehenn do
  @moduledoc """
  Offers a torn book about Hollgrehenn’s ambition.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 169,
        y: 109,
        dir: 1,
        sprite: 111,
        name: "Ambitious Hollgrehenn",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("*Hollgrehenn: The Ambition*")
    |> mes("By Aragham Caul*")
    |> mes(" ")
    |> mes(" ")
    |> mes(" ")
    |> mes(" ")
    |> mes("Publisher:")
    |> mes("Muha Books, Co.")
    |> next()
    |> mes("...")
    |> mes("He would stop at nothing")
    |> mes("to have the greatest weapon")
    |> mes("in the world in his possession.")
    |> mes("He became a smith so that he")
    |> mes("could discern which weapons")
    |> mes("were the most powerful...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("That's strange...")
    |> mes("The next page")
    |> mes("has been torn out.")
    |> close()
  end
end
