defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.Woman do
  @moduledoc """
  Welcomes travelers to Payon and recommends hunting in its nearby cave.

  ## Behavior

  - Tailors one compliment to the visitor's sex.
  - Discusses the cave's danger, preparation, or her fashionable dress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 249,
        y: 156,
        dir: 1,
        sprite: 66,
        name: "Woman",
        scope: :shared,
        unique_name: "Woman#payon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Woman]")
      |> mes("Welcome to Payon.")
      |> mes("You must have had")
      |> mes("a hard time getting")
      |> mes("through the Payon Forest.")
      |> mes("How was your trip?")
      |> next()
      |> mes("[Woman]")
      |> mes(
        "We've been receiving less tourists because of the increasing numbers of monsters outside, so it's quieter nowadays."
      )
      |> next()
      |> mes("[Woman]")
      |> mes(
        " To be honest, things are getting tough because of all those monsters. ^666666*Sigh...*^000000"
      )
      |> next()
      |> mes("[Woman]")
      |> compliment_visitor()

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Woman]")
      |> mes(
        "Hey, I know of a good place for you to hunt. It just so happens that there's a cave in the middle of Payon."
      )
      |> next()
      |> mes("[Woman]")
      |> mes(
        "If you're interested, just head North, pass the forest, and go towards the Northwest. You'll know you've arrived when you're in the place filled with the smell of stinky monsters."
      )
      |> next()
      |> select([
        "It sounds dangerous!",
        "I better prepare myself...!",
        "That's a nice dress you're wearing~"
      ])

    ctx
    |> answer_topic(choice)
    |> close()
  end

  defp compliment_visitor(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      mes(
        ctx,
        "Whoa~! I just noticed those arms of yours look pretty solid. You look pretty strong, guy. Just how many monsters have you killed?!"
      )
    else
      mes(
        ctx,
        "Oooh! I didn't notice before, but you look pretty strong beneath all of that feminine charm."
      )
    end
  end

  defp answer_topic(ctx, 1) do
    ctx
    |> mes("[Woman]")
    |> mes("Oh come on, don't be a coward.")
    |> mes(
      "It's just a simple cave filled with normal monsters. It's quite safe. We've even established an Archer Village near that cave to prevent misfortune incidents. Hohoohoho~ "
    )
  end

  defp answer_topic(ctx, 2) do
    ctx
    |> mes("[Woman]")
    |> mes(
      "Oh don't worry about any preparations. There's a Tool Dealer right in front of the cave, so you can purchase anything you need from my husband, er, that guy~"
    )
  end

  defp answer_topic(ctx, 3) do
    ctx
    |> mes("[Woman]")
    |> mes("Oh hohohoho!")
    |> mes("So you've noticed?")
    |> mes("I hear this is the")
    |> mes("latest trend in Prontera")
    |> mes("these days.")
    |> next()
    |> mes("[Woman]")
    |> mes(
      "Most of the women in this town don't know anything about fashion! My husband bought this for me as"
    )
    |> mes("a present. He makes quite a lot of money, you know. Hohohoho~")
  end

  defp answer_topic(ctx, _choice), do: ctx
end
