defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.PennilessHollgrehenn do
  @moduledoc """
  Offers a book written by Hollgrehenn.

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
        x: 174,
        y: 111,
        dir: 1,
        sprite: 111,
        name: "Penniless Hollgrehenn",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^8B6914*Penniless Hollgrehenn*")
    |> mes(" * Pennyless Hollgrehenn * ")
    |> mes("By Hollgrehenn")
    |> mes(" ")
    |> mes(" ")
    |> mes("Publisher:")
    |> mes("Muha Books, Co.^000000")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("This book looks")
    |> mes("like a total piece of")
    |> mes("crap. I'd have more")
    |> mes("fun getting my teeth")
    |> mes("drilled by a blindfolded")
    |> mes("dentist. Or would I...?")
    |> close()
  end
end
