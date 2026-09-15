defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Crumpler do
  @moduledoc """
  Taunts magic users and reacts to a Wizard's threatened spells.

  ## Behavior

  - Insults Mages, challenges Wizards, invites Sages to drink, and berates everyone else.
  - Lets Wizards threaten Meteor Storm or Lord of Vermilion, or show mercy.
  - Plays the selected spell effect after the corresponding dialogue.

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
    spawn: [
      %{map: "geffen_in", x: 22, y: 125, dir: 1, sprite: 52, name: "Crumpler", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Crumpler]")
      |> mes("Ooooh~!")
      |> mes("You sure are dressed pretty,")
      |> mes("ya fancy schmancy Mage!")
      |> next()

    case class(ctx) do
      :mage -> insult_mage(ctx)
      :wizard -> challenge_wizard(ctx)
      :sage -> address_sage(ctx)
      _ -> denounce_mages(ctx)
    end
  end

  defp insult_mage(ctx) do
    ctx
    |> mes(
      "^3355FFSomeday, you swear to yourself, you will have your bloody revenge on this belligerent drunk for besmirching the proud Mage profession. Someday...^000000"
    )
    |> close()
  end

  defp challenge_wizard(ctx) do
    {ctx, _choice} = select(ctx, ["Actually, I'm a Wizard."])

    {ctx, choice} =
      ctx
      |> mes("[Crumpler]")
      |> mes("I'm so scared!")
      |> mes("A Wizard?! Bwahaha!")
      |> next()
      |> mes("[Crumpler]")
      |> mes(
        "Everyone knows Wizards are all intelligence and no strength! Come on, smart man! Show me how tough you are!"
      )
      |> next()
      |> select(["Meteor Storm!", "Lord of Vermilion!", "Show Mercy."])

    case choice do
      1 -> cast_meteor_storm(ctx)
      2 -> cast_lord_of_vermilion(ctx)
      3 -> show_mercy(ctx)
      _ -> ctx
    end
  end

  defp cast_meteor_storm(ctx) do
    ctx
    |> mes("[Crumpler]")
    |> mes("Huh?")
    |> mes("What'd you just say?")
    |> next()
    |> mes("[Crumpler]")
    |> mes("...")
    |> next()
    |> mes("[Crumpler]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Crumpler]")
    |> mes("Ooooooooh")
    |> mes("crraaaap!")
    |> emotion(:surprise)
    |> next()
    |> mes("[Crumpler]")
    |> mes("Help meeeee!")
    |> specialeffect(:meteorstorm)
    |> close()
  end

  defp cast_lord_of_vermilion(ctx) do
    ctx
    |> mes("[Crumpler]")
    |> mes("Hahahahaah!")
    |> mes("Silly Wizard! Only a monster like Baphomet can handle a big spell like th--")
    |> next()
    |> mes("[Crumpler]")
    |> mes("Oh sweet lord...")
    |> mes("You're serious...")
    |> next()
    |> specialeffect(:lord)
    |> mes("[Crumpler]")
    |> mes("ARRRRRGH~!")
    |> mes("IT BUUUURNS!")
    |> close()
  end

  defp show_mercy(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("No...")
    |> mes("I can only use")
    |> mes("my powers for good.")
    |> next()
    |> mes("[Crumpler]")
    |> mes("Haw haw!")
    |> mes("Good...")
    |> mes("For nothing!")
    |> close()
  end

  defp address_sage(ctx) do
    {ctx, _choice} = select(ctx, ["Actually, sir, I'm a Sage."])

    ctx
    |> mes("[Crumpler]")
    |> mes("A...")
    |> mes("Sage?")
    |> emotion(:question)
    |> next()
    |> mes("[Crumpler]")
    |> mes("I don't know what that is. But I guess it can't be half as bad as a Mage.")
    |> next()
    |> mes("[Crumpler]")
    |> mes("Soooo...")
    |> mes("Wanna drink with me?")
    |> close()
  end

  defp denounce_mages(ctx) do
    ctx
    |> mes("[Crumpler]")
    |> mes("Wait a sec...")
    |> mes("You're not a Mage!")
    |> mes("J-just how drunk am I?!")
    |> next()
    |> mes("[Crumpler]")
    |> mes(
      "Man, I hate Mages with a passion! Always studying and chanting and making taxes high and stuff..."
    )
    |> next()
    |> mes("[Crumpler]")
    |> mes(
      "Taking our jobs, censoring the media, ruining our education system, causing air pollution, starting wars, making rap music..."
    )
    |> close()
  end
end
