defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Scroll do
  @moduledoc """
  Offers an old scroll about upgrading items.

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
      %{map: "yuno_in04", x: 121, y: 109, dir: 1, sprite: 111, name: "Scroll", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou've found an")
      |> mes("antiquated scroll")
      |> mes("that's collected a")
      |> mes("layer of fine dust.^000000")
      |> next()
      |> select(["Peruse", "Leave it alone"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("^8B6914Item Upgrade Introduction")
          |> mes(" ")
          |> mes(" ")
          |> mes(" ")
          |> mes("1. Item Upgrade Definition")
          |> mes(" ")
          |> mes("The key to success when")
          |> mes("upgrading items comes from")
          |> mes("only one place: Your ''Mind.''")
          |> mes(" ")
          |> mes(" ")
          |> mes(" ")
          |> mes("2. Power of a Positive Attitude")
          |> mes("Before trying to upgrade")
          |> mes("an item, plan out how high")
          |> mes("you want to upgrade and how")
          |> mes("much you'll spend beforehand.")
          |> mes("But like all ladies, Lady Luck")
          |> mes("smiles when you fully splurge.^000000")
          |> mes(" ")
          |> mes(" ")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Wait, wait...")
          |> mes("This thing IS old.")
          |> mes("I mean, it's obviously")
          |> mes("written from a patriarchal")
          |> mes("standpoint that promotes")
          |> mes("bipartisan gender roles.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I'm...")
        |> mes("I'm so offended.")
        |> close()

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("This scroll is far too")
        |> mes("primitive. There's been")
        |> mes("all sorts of technological")
        |> mes("reading advances that I can't")
        |> mes("live without... Like pages.")
        |> close()

      _ ->
        ctx
    end
  end
end
