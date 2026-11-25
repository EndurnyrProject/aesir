defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.PrimeMinisterDmitree do
  @moduledoc """
  Prime Minister Dmitree advises visitors to the palace.

  ## Behavior

  - His dialogue and admission to the Csar depend on quest progress.

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
        x: 127,
        y: 89,
        dir: 3,
        sprite: 967,
        name: "Prime Minister Dmitree",
        scope: :shared,
        unique_name: "Prime Minister Dmitree#m"
      }
    ]

  @impl true
  def on_talk(ctx) do
    winter = get_char_var(ctx, :mos_nowinter, 0)

    cond do
      winter in 12..13 ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("You are in trouble if")
        |> mes("you conspire against the Csar,")
        |> mes("so, make your actions carefully,")
        |> mes("and if you want to clean yourself")
        |> mes("from suspicion... do everything you")
        |> mes("can to prove your innocence.")
        |> close()

      winter == 14 ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("You have just cleared your name,")
        |> mes("but... we don't trust you wholly yet.")
        |> next()
        |> mes("[Prime Minister Dmitree]")
        |> mes("I can't trust you, but...")
        |> mes("if you succeed in taking hold of")
        |> mes("the summer... I might be able to.")
        |> close()

      winter == 20 ->
        weather_report(ctx)

      true ->
        whale_dialogue(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp whale_dialogue(ctx) do
    whale = get_char_var(ctx, :mos_whale_edq, 0)

    cond do
      whale < 16 ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes(
          "You are a foreign traveler. This is the Moscovia Palace, home of Csar Aleksay the Third. Extending your every courtesy here... is not bad manners."
        )
        |> close()

      whale == 16 ->
        ask_business(ctx)

      whale == 17 ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("I already announced you,")
        |> mes("so go see him and speak to him directly.")
        |> close()

      whale > 17 and whale < 35 ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("Now, our dear Csar needs a rest.")
        |> mes("You should do your duty and go find the whale island.")
        |> close()

      whale in [35, 38] ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("Ah! You've come back.")
        |> mes("I will request for you to see him immediately.")
        |> close()

      whale == 39 ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("I don't want to hear your terrible ")
        |> mes("performance anymore so, go out away.")
        |> close()

      whale == 40 ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("What's up? Dear Chare is taking a rest.")
        |> mes("If you have nothing special, go out.")
        |> close()

      whale == 41 ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("Your Gusli performance was so touching.")
        |> mes("Unforgettable! Whenever you are here, please allow us to hear that tune again.")
        |> close()

      true ->
        ctx
        |> mes("[Prime Minister Dmitree]")
        |> mes("You are a foreign traveler. This is a palace")
        |> mes("which lives Alexei the Third.")
        |> mes("Extend you every courtesy don't not bad manner.")
        |> close()
    end
  end

  defp weather_report(ctx) do
    ctx
    |> mes("[Prime Minister Dmitree]")
    |> mes("We know that you mean well.")
    |> mes("But we can't fully trust you,")
    |> mes("so we kept an eye on your movements.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("I heard that you performed")
    |> mes("witchcraft at the palace square...")
    |> mes("so, I ordered scholars to")
    |> mes("investigate the weather.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("The results from taking observation")
    |> mes("of the weather, are the reducing")
    |> mes("change of temperature, and that the")
    |> mes("highest temperature is now stabilized.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("I don't know what this may mean, by")
    |> mes("way of principle, but I've decided")
    |> mes("to admit the facts.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("Already, our dear Csar knows.")
    |> mes("I finished the report.")
    |> mes("Go and announce it to him.")
    |> close()
  end

  defp ask_business(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Prime Minister Dmitree]")
      |> mes("Traveler, why have you come to the Csar's Palace?")
      |> next()
      |> select(["Just to look around.", "To see the dear Csar."])

    if choice == 1 do
      ctx
      |> mes("[Prime Minister Dmitree]")
      |> mes("If so... look around with caution. Do not bother the Csar.")
      |> next()
      |> mes("[Prime Minister Dmitree]")
      |> mes("Moscovia welcomes all travelers such as yourself!")
      |> next()
      |> mes("[Prime Minister Dmitree]")
      |> mes(
        "Marvelously, our dear Csar likes it very much when interesting stories are often told to him."
      )
      |> close()
    else
      ask_audience(ctx)
    end
  end

  defp ask_audience(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Prime Minister Dmitree]")
      |> mes(
        "Did you come to see our dear Csar? If so, tell me your business with him in advance."
      )
      |> next()
      |> select(["I'd like to say hello.", "I have an adventure story for him."])

    if choice == 1 do
      ctx
      |> mes("[Prime Minister Dmitree]")
      |> mes(
        "I will tell him directly about your business. You don't need to worry yourself with the Csar."
      )
      |> close()
    else
      ctx
      |> mes("[Prime Minister Dmitree]")
      |> mes(
        "I wonder what sort of things have happened to you... The Csar will be very pleased to hear your stories."
      )
      |> next()
      |> mes("[Prime Minister Dmitree]")
      |> mes(
        "I will admit you. If our dear Csar is satisfied with your story, he will give you a big prize."
      )
      |> set_char_var(:mos_whale_edq, 17)
      |> close()
    end
  end
end
