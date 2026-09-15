defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Stacey do
  @moduledoc """
  Reacts to Orc headgear or wonders about Orc courtship.

  ## Behavior

  - Gives gender-specific reactions to an Orc Helm or Helmet of Orc Hero.
  - Otherwise discusses Orc culture and dating.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "geffen", x: 111, y: 48, dir: 0, sprite: 101, name: "Stacey", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case getequipid(ctx, 6) do
      2299 -> admire_orc_helm(ctx)
      5094 -> admire_orc_hero_helm(ctx)
      _ -> discuss_orcs(ctx)
    end
  end

  defp admire_orc_helm(ctx) do
    ctx =
      ctx
      |> mes("[Stacey]")
      |> mes("Oh...!")
      |> mes("Is that an Orc Helm you're wearing?! That's so cool! Wow...")
      |> next()
      |> mes("[Stacey]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx |> mes("You look so...") |> mes("Rugged and manly~")
      else
        ctx |> mes("Oooh~!") |> mes("I'm so jealous!")
      end

    close(ctx)
  end

  defp admire_orc_hero_helm(ctx) do
    ctx =
      ctx
      |> mes("[Stacey]")
      |> mes("Oh...")
      |> mes("Wow...")
      |> next()
      |> mes("[Stacey]")
      |> mes("That's...")
      |> mes("That's a Helmet")
      |> mes("of Orc Hero!")
      |> next()
      |> mes("[Stacey]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes("It's...")
        |> mes(
          "It's like you're surrounded by this incredibly masculine aura! Oooh~! You must be irresistible to all the girls!"
        )
        |> next()
        |> emotion(:throb)
        |> mes("[Stacey]")
        |> mes("And I'm no exception.")
      else
        ctx
        |> mes("Goodness, you must be so strong!")
        |> mes("But I thought only members of the Orc Tribe could wear those?")
      end

    close(ctx)
  end

  defp discuss_orcs(ctx) do
    ctx
    |> mes("[Stacey]")
    |> mes("Hello~!")
    |> mes("Oh, aren't you")
    |> mes("an adventurer?")
    |> next()
    |> mes("[Stacey]")
    |> mes(
      "Have you ever seen any Orcs from the Demi-Human tribe? If you go down southward from here, I think you can find Orcs in the deep forest."
    )
    |> next()
    |> mes("[Stacey]")
    |> mes(
      "I hear that Orcs have their own culture and language, supposedly just like us humans. Does that mean Orcs go on dates...?"
    )
    |> next()
    |> mes("[Stacey]")
    |> mes(
      "You know, where they tenderly whisper sweet nothings and then... Oh! I really want to know!"
    )
    |> close()
  end
end
