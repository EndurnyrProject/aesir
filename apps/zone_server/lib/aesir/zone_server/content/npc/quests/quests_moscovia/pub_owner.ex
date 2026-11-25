defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.PubOwner do
  @moduledoc """
  The pub owner guides visitors searching for Mikhail.

  ## Behavior

  - Offers drinks and directs the player to Victor during the search.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 141,
        y: 212,
        dir: 3,
        sprite: 964,
        name: "Pub Owner",
        scope: :shared,
        unique_name: "Pub Owner#mos"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 do
      ctx
      |> mes("- Please stop here!! -")
      |> mes("- You're carrying too many items -")
      |> mes("- Please try again -")
      |> mes("- after using the kafra service -")
      |> close()
    else
      speak(ctx, get_char_var(ctx, :mos_swan, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp speak(ctx, 7) do
    {ctx, choice} =
      ctx
      |> mes("[Pub Owner]")
      |> mes("We've got another wanderer here")
      |> mes("Welcome to our pub.")
      |> mes("I'm Alexandre of ^3131FF'Pub Stream'^000000. You can call me 'Sasha'.")
      |> next()
      |> select(["Ask him about Mikhail.", "Order a drink."])

    if choice == 1, do: ask_about_mikhail(ctx), else: order_first_drink(ctx)
  end

  defp speak(ctx, 8), do: order_second_drink(ctx)

  defp speak(ctx, 9) do
    ctx |> mes("[Pub Owner]") |> mes("Have you spoken to Victor?") |> close()
  end

  defp speak(ctx, _stage) do
    ctx
    |> mes("[Pub Owner]")
    |> mes("Welcome to our pub.")
    |> mes("I'm Alexandre of ^3131FF'Stream Pub'^000000. But, everyone calls me 'Sasha'.")
    |> mes("It's a fine day today. I feel like going out.")
    |> close()
  end

  defp ask_about_mikhail(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Sasha, has a little boy called 'Mikhail' came here?")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("Are you talking about the cute little boy? Yes he has came here.")
      |> mes("He looked pale and needed a high-strength adhesive .")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("So what did you say ?")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("I don't know well about that thing.")
      |> mes("However, I know a person who may know about that so I introduced him to Mikhail.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Who's that person?")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("It's Victor over there.")
      |> mes("He's very careful about details so we call him ^3131FF'hedgehog Victor'^000000.")
      |> mes("No one knows about it well except him.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Sasha, thanks a lot!")
    |> next()
    |> mes("[Pub Owner]")
    |> mes("You're welcome.")
    |> set_char_var(:mos_swan, 8)
    |> close()
  end

  defp order_first_drink(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Pub Owner]")
      |> mes("Although you may be an experienced adventurer, you look so young.")
      |> mes("I recommend you these drinks. Which one will you take?")
      |> next()
      |> select(["Milk - 1000z", "Sticky_Herb juice - 1000z", "They are all expensive!"])

    ctx = set_local(ctx, :j, choice - 1)

    cond do
      get_local(ctx, :j, 0) == 2 ->
        ctx |> mes("[Pub Owner]") |> mes("Hahaha, too much for you eh cheapskate.") |> close()

      zeny(ctx) > 999 ->
        serve_first_drink(ctx)

      true ->
        offer_water(ctx)
    end
  end

  defp serve_first_drink(ctx) do
    ctx = ctx |> pay_zeny(1000) |> set_char_var(:mos_swan, 9)

    ctx =
      if get_local(ctx, :j, 0) == 0 do
        give_item(ctx, 519, 1)
      else
        give_item(ctx, 531, 1)
      end

    ctx =
      ctx
      |> mes("[Pub Owner]")
      |> mes("Here you are. This is what you ordered.")
      |> mes("How do you like Moscovia?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Yes, it's beautiful and gorgeous.")
      |> mes("Sasha, most of all, can you answer one question?")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("About what?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Has Mikhail come here?")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("Yes he has.")
      |> mes("He looked pale and needed a high-strength adhesive.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("So what happened?")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("I don't know much about adhesives.")
      |> mes("But, I know a person who may know about them so I introduced Mikhail to him.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Who's this person?")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("It's Victor over there.")
      |> mes("He's very careful about details so we call him ^3131FF'Hedgehog Victor'^000000.")
      |> mes("No one knows adhesives as well as he does.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Sasha, thanks a lot!")
    |> next()
    |> mes("[Pub Owner]")
    |> mes("You're welcome.")
    |> close()
  end

  defp order_second_drink(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Pub Owner]")
      |> mes("While I work in this pub, I can hear stories from all around the world.")
      |> mes("They are all heroes of their life.")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("Each story interests me so a day passes quick.")
      |> mes("That's why I love my job.")
      |> next()
      |> mes("[Pub Owner]")
      |> mes("Well, do you have some stories for me? or you've got something to ask me.")
      |> mes("I recommend you those drinks.")
      |> next()
      |> select(["Milk - 1000z", "Apple juice - 1000z", "They are all expensive!"])

    ctx = set_local(ctx, :s, choice)

    cond do
      get_local(ctx, :s, 0) == 3 ->
        ctx |> mes("[Pub Owner]") |> mes("Hahaha, Here is the sightseeing place.") |> close()

      zeny(ctx) > 999 ->
        serve_second_drink(ctx)

      true ->
        offer_water(ctx)
    end
  end

  defp serve_second_drink(ctx) do
    ctx = ctx |> pay_zeny(1000) |> set_char_var(:mos_swan, 9)

    ctx =
      if get_local(ctx, :s, 0) == 1 do
        give_item(ctx, 519, 1)
      else
        give_item(ctx, 531, 1)
      end

    ctx
    |> mes("[Pub Owner]")
    |> mes("Here you are. This is what you ordered.")
    |> mes("Enjoy yourself.")
    |> close()
  end

  defp offer_water(ctx) do
    ctx
    |> mes("[Pub Owner]")
    |> mes("You'll need a lot of money while you're traveling.")
    |> mes("If you don't have enough money, I'll offer you a glass of water.")
    |> close()
  end
end
