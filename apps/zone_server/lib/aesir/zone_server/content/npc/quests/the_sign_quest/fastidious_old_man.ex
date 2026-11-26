defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.FastidiousOldMan do
  @moduledoc """
  Helps translate an ancient document during The Sign quest.

  ## Behavior

  - Requests glasses and the document, then translates them after a wait.
  - Answers questions about Geffen and the Sobbing Starlight.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 165,
        y: 83,
        dir: 4,
        sprite: 755,
        name: "Fastidious Old Man",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if checkweight(ctx, [{908, 200}]) == 0 do
      ctx
      |> mes("^3355FFWait a second! Right now,")
      |> mes(
        "you have too many items in your inventory. Please come back after you've freed up more inventory space.^000000"
      )
      |> close()
    else
      talk(mes(ctx, "[Frank]"))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk(ctx) do
    case get_char_var(ctx, :sign_q, 0) do
      stage when stage < 77 ->
        ctx
        |> mes("My back~")
        |> mes("It's so sore!")
        |> mes("And my eyes are")
        |> mes("hurting worse and worse.")
        |> mes("^333333*Sigh*^000000 I'm getting old...")
        |> close()

      77 ->
        ctx |> vision() |> set_char_var(:sign_q, 78) |> close()

      78 ->
        offer_glasses(ctx)

      79 ->
        if Enum.random(1..50) == 9 do
          ctx
          |> mes(
            "I've finally completed the translation. It was a challenge deciphering the meaning of some"
          )
          |> mes(
            "of these words. Even translated in our own language, this contents of this text are fairly ambiguous."
          )
          |> next()
          |> mes("[Frank]")
          |> mes(
            "Well, I've written down the best translation that I could for you. It's been a long time since I've had this kind of challenge. Thanks, youngster."
          )
          |> mes("Ha ha ha~")
          |> set_char_var(:sign_q, 80)
          |> give_item(7274, 1)
          |> close()
        else
          ctx
          |> mes(
            "I'm sorry, but I haven't finished translating this text. It's taking quite a long time since I don't have any reference material for this particular language. Why"
          )
          |> mes("don't you come back later?")
          |> close()
        end

      _ ->
        ctx
        |> mes("There are many things out")
        |> mes(
          "there that defy our understanding of the world and are beyond our imagination. Many fear the unknown, but the truly brave will always seek out the truth."
        )
        |> close()
    end
  end

  defp vision(ctx) do
    ctx
    |> mes("My vision's getting")
    |> mes("blurrier and I get headaches")
    |> mes("when I read. I guess this old")
    |> mes("man's got no choice but to get")
    |> mes("some sort of seeing aid...")
  end

  defp offer_glasses(ctx) do
    if count_item(ctx, 2203) > 0 and count_item(ctx, 7275) > 0 do
      {ctx, choice} =
        ctx
        |> vision()
        |> next()
        |> select(["Wait, I've got a pair of glasses...", "Pass on by."])

      case choice do
        1 ->
          ctx
          |> mes("[Frank]")
          |> mes("Oh, you've brought me")
          |> mes("these Glasses? Thanks")
          |> mes("so much, youngster. Now that")
          |> mes("I can see better, what can")
          |> mes("I do for you in return?")
          |> next()
          |> discuss()

        2 ->
          lament(ctx)

        _ ->
          ctx
      end
    else
      ctx |> vision() |> close()
    end
  end

  defp lament(ctx) do
    ctx
    |> mes("[Frank]")
    |> mes("Oooh~")
    |> mes("How will I ever")
    |> mes("be able to continue")
    |> mes("my life's work? I'm")
    |> mes("helpless if I can't read...")
    |> close()
  end

  defp discuss(ctx) do
    {ctx, choice} =
      select(ctx, [
        "About Geffen's Hidden Power",
        "About Sobbing Starlight",
        "Interpret Ancient Document"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Frank]")
        |> mes("Geffen's hidden power?")
        |> mes(
          "I don't know much about it, but I'm sure that Geffen Tower is more than just a simple building. I'm sure it was created to restrain or contain some powerful force."
        )
        |> next()
        |> mes("[Frank]")
        |> mes(
          "It's even possible that the fountain in front of Geffen Tower also plays the same role, but I've got no hard evidence. Since I'm not too interested in Geffen, I haven't really investigated..."
        )
        |> next()
        |> mes("[Frank]")
        |> mes("Still...")
        |> mes(
          "There's a strong possibility that some enormous power is being sealed beneath the Geffen Tower."
        )
        |> next()
        |> discuss()

      2 ->
        ctx
        |> mes("[Frank]")
        |> mes("The Sobbing Starlight?")
        |> mes(
          "To the experts, it's known as God's Tear Drop. Now, some believe it was created from the voice of God."
        )
        |> next()
        |> mes("[Frank]")
        |> mes(
          "Of course, it probably isn't made from God's voice or tear drops, but who knows? In any case, it's said that something's written in the Sobbing Starlight. What ever it is, it must be something important..."
        )
        |> next()
        |> discuss()

      3 ->
        ctx
        |> mes("[Frank]")
        |> mes("I don't believe it!")
        |> mes(
          "This is... I see. You want me to translate this ancient language. Ah, you're rather fortunate. I'm probably the only person in the world who can translate this."
        )
        |> next()
        |> mes("[Frank]")
        |> mes(
          "Hmm, as far as I can tell, this is a sophisticated language spoken by the ancient gods. It's complex and confusing, but I'll do my best for you. Come back to me later, and I'll what I've learned."
        )
        |> delitem(2203, 1)
        |> delitem(7275, 1)
        |> set_char_var(:sign_q, 79)
        |> close()

      _ ->
        ctx
    end
  end
end
