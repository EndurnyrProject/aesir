defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.ForeignMerchant do
  @moduledoc """
  A foreign merchant asks for a refreshing drink in Morocc.

  ## Behavior

  - His conversation changes with the quest and reveals a message from Bekento.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 77,
        y: 167,
        dir: 4,
        sprite: 880,
        name: "Foreign Merchant",
        scope: :shared,
        unique_name: "Foreign Merchant#aru1",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :aru_vol, 0) != 27 -> default_greeting(ctx)
      get_char_var(ctx, :aru_em, 0) == 0 -> introduce(ctx)
      get_char_var(ctx, :aru_em, 0) > 0 and get_char_var(ctx, :aru_em, 0) < 7 -> waiting(ctx)
      get_char_var(ctx, :aru_em, 0) == 7 -> offer_drink(ctx)
      true -> sightseeing(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp introduce(ctx) do
    {ctx, _} =
      ctx
      |> emotion(:think)
      |> mes("[Foreign Merchant]")
      |> mes("I never thought the desert")
      |> mes("would be this hot! They built")
      |> mes("a town here?! How can they call")
      |> mes("this place inhabitable! What's")
      |> mes("more, the crowds make things")
      |> mes("around here so much hotter!")
      |> next()
      |> emotion(:think)
      |> mes("[Foreign Merchant]")
      |> mes("I heard that I could make")
      |> mes("a killing in Morocc, which is")
      |> mes("why I moved my business here.")
      |> mes("But it looks like the weather")
      |> mes("is going to kill me first!")
      |> next()
      |> select(["How did you hear of Morocc?"])

    ctx =
      ctx
      |> emotion(:think)
      |> mes("[Foreign Merchant]")
      |> mes("I... I just told you.")
      |> mes("I heard that Morocc is")
      |> mes("full customers willing to")
      |> mes("buy things at premium prices.")
      |> mes("Ugh, but it's a burning hell!")
      |> next()
      |> emotion(:sweat)
      |> mes("[Foreign Merchant]")
      |> mes("I don't even care about making")
      |> mes("money anymore! I just want to")
      |> mes("be somewhere cool, drinking")
      |> mes("a nice, frosty drink! You know,")
      |> mes("I might just leave this town")
      |> mes("tomorrow. Forget this desert!")
      |> next()
      |> emotion(:cry)

    ctx
    |> emotion(:sweat, playerattached(ctx))
    |> mes("[Foreign Merchant]")
    |> mes("Ah, that's right. Don't they")
    |> mes("sell some sweet, heavenly")
    |> mes("drink around here? You know,")
    |> mes("near the pond in the middle")
    |> mes("of Morocc? Before I leave,")
    |> mes("I want to taste that drink...")
    |> set_char_var(:aru_em, 1)
    |> setquest(2129)
    |> close()
  end

  defp waiting(ctx) do
    ctx
    |> mes("[Foreign Merchant]")
    |> mes("Say, isn't there a wandering")
    |> mes("drink merchant near the pond")
    |> mes("in the middle of Morocc. Oh,")
    |> mes("what I would do to have that")
    |> mes("delicious drink he's selling...")
    |> next()
    |> mes("[Foreign Merchant]")
    |> mes("Oh, the heat's getting to me...")
    |> mes("And I'm running out of sweat")
    |> mes("to sweat... I think I'm going")
    |> mes("to faint soon! I need a drink!")
    |> close()
  end

  defp offer_drink(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Foreign Merchant]")
      |> mes("*Pant Pant*")
      |> mes("*Sweat*")
      |> next()
      |> select(["Give Fruit Wine", "Quietly Watch Him"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Foreign Merchant]")
          |> mes("Oh, thank you! This")
          |> mes("smells so heavenly...")
          |> mes("Is this that famous drink")
          |> mes("that I keep hearing about?")
          |> next()
          |> mes("^3355FF*Gulp Gulp Gulp Gulp*^000000")
          |> mes("^3355FF*Gulp Gulp Gulp Gulp*^000000")
          |> mes("^3355FF*Gulp Gulp Gulp Gulp*^000000")
          |> mes("^3355FF*Gulp Gulp Gulp Gulp*^000000")
          |> mes("^3355FF*Gulp Gulp Gulp Gulp*^000000")
          |> next()
          |> emotion(:throb)
          |> mes("[Foreign Merchant]")
          |> mes("Ahhh! That hit the spot!")
          |> mes("It's so refreshing and so")
          |> mes("exotic, like... Like... Those")
          |> mes("dancers in Comodo! Ahhhh!")
          |> mes("Thank you so much, friend!")
          |> next()
          |> mes("[Foreign Merchant]")
          |> mes("There must be some")
          |> mes("way I can repay you.")
          |> mes("Ah, here we go. Take it.")

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("Isn't your name, ", char_name(ctx, 0)), "?"))
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("What th--?")
          |> mes("How did you know?")
          |> next()
          |> mes("^3355FFThe merchant giggled,")
          |> mes("note from under his sleeve.")
          |> mes("You open the note, and")
          |> mes("read its message.^000000")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("^666666", char_name(ctx, 0)), "."))
          |> mes(" ")
          |> mes("The time for us to act")
          |> mes("has come once again.")
          |> mes("Please come see me")
          |> mes("once you get the chance.")
          |> mes(" ")
          |> mes(" - Bekento^000000")
          |> next()

        ctx = emotion(ctx, :huk, playerattached(ctx))

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("So... This means...")
          |> mes("You're not really a")
          |> mes("merchant, are you?")
          |> next()
          |> emotion(:merong)
          |> mes("^3355FFThe merchant quietly")
          |> mes("looks at you with a")
          |> mes("mischievous grin.^000000")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("So you asked me to get")
          |> mes("you a drink as an excuse")
          |> mes("just to talk to you?!")

        ctx = ctx |> emotion(:cry, playerattached(ctx)) |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Oh well, thanks for")
        |> mes("bringing me the note.")
        |> mes("But I'm not buying you")
        |> mes("any more drinks, got it?")
        |> next()
        |> mes("[Foreign Merchant]")
        |> mes("Heh, understood.")
        |> mes("Now why don't you")
        |> mes("speak to him now?")
        |> mes("Good luck!")
        |> set_char_var(:aru_em, 8)
        |> changequest(2130, 2131)
        |> close()

      2 ->
        ctx
        |> mes("[Foreign Merchant]")
        |> mes("Wha-- Do you just")
        |> mes("enjoy watching me")
        |> mes("slowly sweat to death?")
        |> close()

      _ ->
        ctx
    end
  end

  defp sightseeing(ctx) do
    ctx
    |> mes("[Foreign Merchant]")
    |> mes("Well, I'm already here.")
    |> mes("I guess I may as well go")
    |> mes("sightseeing around Morocc.")
    |> mes("*Pant Pant* But it's so hot!")
    |> close()
  end

  defp default_greeting(ctx) do
    ctx
    |> mes("[Foreign Merchant]")
    |> mes("I never thought the desert")
    |> mes("would be this hot! They built")
    |> mes("a town here?! How can they call")
    |> mes("this place inhabitable! What's")
    |> mes("more, the crowds make things")
    |> mes("around here so much hotter!")
    |> close()
  end

  defp ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_vol, 0) == 27 and get_char_var(ctx, :aru_em, 0) == 0 do
      ctx
      |> mes("[Foreign Merchant]")
      |> mes("*Pant Pant*")
      |> mes("Man, I think I'm going")
      |> mes("to die from all this heat!")
      |> close()
    else
      ctx
    end
  end
end
