defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Customer do
  @moduledoc """
  Shares Buchi's drunken complaints with married and unmarried patrons.

  ## Behavior

  - Offers a free drink that knocks out an unmarried patron who lacks enough zeny to drink.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii_in",
        x: 43,
        y: 115,
        dir: 0,
        sprite: 97,
        name: "Customer",
        scope: :shared,
        unique_name: "Customer#jaw_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Buchi]")

    if Rathena.truthy?(getpartnerid(ctx)) do
      address_married_patron(ctx)
    else
      address_single_patron(ctx)
    end
  end

  defp address_single_patron(ctx) do
    if zeny(ctx) > 99 do
      ctx
      |> mes("Grrrr...")
      |> mes("Damn! I don't")
      |> mes("like this place!")
      |> mes("I don't like this at all!")
      |> next()
      |> mes("[Buchi]")
      |> mes(
        "I can't believe my eyes! Everyone else looks disgustingly happy! It makes me feel so miserable!"
      )
      |> mes("You agree, don't you?!")
      |> next()
      |> mes("[Buchi]")
      |> mes("Grrrr...")
      |> mes("Bartender!")
      |> mes("Give me one more!")
      |> close()
    else
      offer_free_drink(ctx)
    end
  end

  defp offer_free_drink(ctx) do
    ctx
    |> mes("Hey, why aren't you drinking?")
    |> mes("I guess you're all out of dough.")
    |> mes(
      "But I know how you feel. Disgusted with all the lovey dovey around this place, aren't you?"
    )
    |> next()
    |> mes("[Buchi]")
    |> mes("Heh.")
    |> mes("Lemme buy")
    |> mes("you a drink!")
    |> next()
    |> mes("[Buchi]")
    |> mes(
      "Drink this at once, and forget about your miserable life! Cheer up, you got the whole future ahead of you and a drink in front of you! Come on, now~!"
    )
    |> next()
    |> mes("^3355FFHe ordered a JJ special for me.^000000")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Damn...!")
    |> mes("Damn! I will be")
    |> mes("the one who laughs last!")
    |> next()
    |> mes("^3355FFYou drank to your fill.^000000")
    |> close()
    |> percent_heal(hp: -100, sp: 0)
  end

  defp address_married_patron(ctx) do
    ctx
    |> mes("You look happy...")
    |> mes("I hope you'll be")
    |> mes("able to feel that")
    |> mes("way forever...")
    |> mes(" ")
    |> mes("^666666*Hiccup...!*^000000")
    |> close()
  end
end
