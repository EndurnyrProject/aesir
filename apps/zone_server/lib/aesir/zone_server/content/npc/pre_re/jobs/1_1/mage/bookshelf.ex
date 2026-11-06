defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Mage.Bookshelf do
  @moduledoc """
  Explains the four recipes used in the Mage guild admission test.

  ## Behavior

  - Lists each solution’s ingredients, solvent, magic powder serial code, and catalyst.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/mage.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "geffen_in",
        x: 177,
        y: 112,
        dir: 4,
        sprite: 111,
        name: "Bookshelf",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, solution} =
      ctx
      |> mes("[Guide Book]")
      |> mes(
        "This Guide Book is the property of the Geffen Mage Association. Please handle with care."
      )
      |> next()
      |> select([
        "Solution No. 1.",
        "Solution No. 2.",
        "Solution No. 3.",
        "Solution No. 4.",
        "Close."
      ])

    case solution do
      1 ->
        ctx
        |> mes("[Mage Test Solution No. 1]")
        |> mes("* Ingredients List *")
        |> mes("2 Jellopy")
        |> mes("3 Fluff")
        |> mes("1 Milk")
        |> next()
        |> mes("[Mage Test Solution No. 1]")
        |> mes("* Solvent Agent *")
        |> mes("Payon Solution")
        |> mes("Where to Find:")
        |> mes("A small spring in Payon, the Archer Village.")
        |> next()
        |> mes("[Mage Test Solution No. 1]")
        |> mes("* Magic Power Serial Code *")
        |> mes("8472")
        |> next()
        |> mes("[Mage Test Solution No. 1]")
        |> mes("* Catalyst *")
        |> mes("Yellow Gemstone")
        |> mes("(Provided by")
        |> mes("Mixing Machine)")
        |> close()

      2 ->
        ctx
        |> mes("[Mage Test Solution No. 2]")
        |> mes("* Ingredients List *")
        |> mes("3 Jellopy")
        |> mes("1 Fluff")
        |> mes("1 Milk")
        |> next()
        |> mes("[Mage Test Solution No. 2]")
        |> mes("* Solvent Agent *")
        |> mes("None")
        |> next()
        |> mes("[Mage Test Solution No. 2]")
        |> mes("* Magic Power Serial Code *")
        |> mes("3735")
        |> next()
        |> mes("[Mage Test Solution No. 2]")
        |> mes("* Catalyst *")
        |> mes("Red Gemstone")
        |> mes("(Provided by")
        |> mes("Mixing Machine)")
        |> close()

      3 ->
        ctx
        |> mes("[Mage Test Solution No. 3]")
        |> mes("* Ingredients List *")
        |> mes("6 Jellopy")
        |> mes("1 Fluff")
        |> next()
        |> mes("[Mage Test Solution No. 3]")
        |> mes("* Solvent Agent *")
        |> mes("Payon Solution")
        |> mes("Where to Find:")
        |> mes("A small spring in Payon, the Archer Village.")
        |> next()
        |> mes("[Mage Test Solution No. 3]")
        |> mes("* Magic Power Serial Code *")
        |> mes("2750")
        |> next()
        |> mes("[Mage Test Solution No. 3]")
        |> mes("* Catalyst *")
        |> mes("Blue Gemstone")
        |> mes("(Provided by")
        |> mes("Mixing Machine)")
        |> close()

      4 ->
        ctx
        |> mes("[Mage Test Solution No. 4]")
        |> mes("* Ingredients List *")
        |> mes("2 Jellopy")
        |> mes("3 Fluff")
        |> next()
        |> mes("[Mage Test Solution No. 4]")
        |> mes("* Solvent Agent *")
        |> mes("Morocc Solution")
        |> mes("Where to Find:")
        |> mes("A small spring near entrance of pyramid in Morocc.")
        |> next()
        |> mes("[Mage Test Solution No. 4]")
        |> mes("* Magic Power Serial Code *")
        |> mes("5429")
        |> next()
        |> mes("[Mage Test Solution No. 4]")
        |> mes("* Catalyst *")
        |> mes("1 carat Diamond")
        |> mes("(Provided by")
        |> mes("Mixing Machine)")
        |> close()

      _ ->
        close(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
