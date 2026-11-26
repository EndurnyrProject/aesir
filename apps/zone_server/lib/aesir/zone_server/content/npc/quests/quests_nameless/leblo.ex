defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Leblo do
  @moduledoc """
  Leblo is a Geffen jewel merchant.

  ## Behavior

  - He trades information for medicine and later discusses the cursed jewel.

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
    spawn: [%{map: "geffen", x: 128, y: 153, dir: 3, sprite: 883, name: "Leblo", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :diamond_edq, 0) do
      stage when stage in [15, 16] ->
        request_medicine(ctx)

      17 ->
        ctx
        |> mes("[Leblo]")
        |> mes("Please look for a female")
        |> mes("doctor named ^0000FFWola^000000 in Payon.")
        |> mes("Do what you can to get my")
        |> mes("medicine from her... Oh,")
        |> mes("and try to be nice~ ")
        |> close()

      21 ->
        reveal_information(ctx)

      22 ->
        ctx
        |> mes("[Leblo]")
        |> mes("You should talk with one")
        |> mes("of the investigators of the")
        |> mes("Rogue Guild if you want to")
        |> mes("learn more about the Z Gang.")
        |> mes("Pretty useful info, huh?")
        |> mes("Take care, my friend.")
        |> close()

      26 ->
        discuss_jewel(ctx, get_char_var(ctx, :jewel_nd, 0))

      _ ->
        ctx
        |> mes("[Leblo]")
        |> mes("Hello, are you interested")
        |> mes("in buying or selling any")
        |> mes("precious jewels?")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp request_medicine(ctx) do
    ctx =
      ctx
      |> mes("[Leblo]")
      |> mes("Oh, I've heard about")
      |> mes("you. You're the one that's")
      |> mes("been asking questions about")
      |> mes("the Diamond of Destruction.")
      |> next()

    {ctx, choice} =
      ctx
      |> emotion(:huk, playerattached(ctx))
      |> mes("[Leblo]")
      |> mes("Don't be so suprised:")
      |> mes("word travels fast in the")
      |> mes("jewel industry. Well, if you")
      |> mes("want to learn more, you'll")
      |> mes("have to do something for")
      |> mes("me first. We have a deal?")
      |> next()
      |> select(["Deal.", "No, thanks."])

    case choice do
      1 ->
        ctx
        |> mes("[Leblo]")
        |> mes("I've been suffering back")
        |> mes("pain lately, and none of")
        |> mes("the medicines do any good.")
        |> mes("I resorted to seeing this")
        |> mes("famous doctor in Payon, but")
        |> mes("then I totally screwed it up.")
        |> next()
        |> mes("[Leblo]")
        |> mes("She was such a nag, and")
        |> mes("I said something... unpleasant")
        |> mes("to her. Now she refuses to")
        |> mes("examine me! But if I sent")
        |> mes("you, then you could get")
        |> mes("some medicine for me.")
        |> next()
        |> mes("[Leblo]")
        |> mes("She knows my symptoms")
        |> mes("so if you make her happy,")
        |> mes("she'll give you my medicine...")
        |> mes("I hope. Anyway, her name is")
        |> mes("^0000FFWola^000000, and she's in Payon.")
        |> changequest(3110, 3111)
        |> set_char_var(:diamond_edq, 17)
        |> close()

      2 ->
        ctx
        |> mes("[Leblo]")
        |> mes("Oh, yeah? Well, that's")
        |> mes("fine with me. I don't")
        |> mes("have anything to lose.")
        |> close()

      _ ->
        ctx
    end
  end

  defp reveal_information(ctx) do
    ctx =
      ctx
      |> mes("[Leblo]")
      |> mes("Oh? Is that... Is that my")
      |> mes("medicine? Thank goodness!")
      |> mes(" Hm? Oh, so I misunderstood")
      |> mes(" her. I thought she was awfully")
      |> mes(" arrogant, but she was just")
      |> mes(" concerned for my health.")
      |> next()
      |> mes("[Leblo]")
      |> mes("I better make it a point")
      |> mes("to properly apologize to")
      |> mes("her the next time I see her.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...............................")
    |> mes("...............................")
    |> mes("...............................")
    |> next()
    |> mes("[Leblo]")
    |> mes("Right, I need to tell")
    |> mes("you about the Diamond of")
    |> mes("Destruction. Listen carefully.")
    |> mes("A while ago, a young couple")
    |> mes("tried to sell me that very")
    |> mes("jewel. Suspicious, eh?")
    |> next()
    |> mes("[Leblo]")
    |> mes("I had no interest in")
    |> mes("buying it, so I actually")
    |> mes("offered them a much lower")
    |> mes("price than they hoped.")
    |> mes("Now that I think about it...")
    |> next()
    |> mes("[Leblo]")
    |> mes("That man and woman looked")
    |> mes("like the members of that")
    |> mes("infamous Z Gang. Heh!")
    |> mes("I should have reported it,")
    |> mes("but... You know. Back")
    |> mes("pain and all that.")
    |> next()
    |> mes("[Leblo]")
    |> mes("I hear the Rogue Guild")
    |> mes("is secretly investigating")
    |> mes("the Z Gang, so that couple")
    |> mes("must have plenty of enemies.")
    |> mes("So... Yeah. The Z Gang has")
    |> mes("the Diamond of Destruction.")
    |> next()
    |> mes("[Leblo]")
    |> mes("You should talk with one")
    |> mes("of the investigators of the")
    |> mes("Rogue Guild if you want to")
    |> mes("learn more about the Z Gang.")
    |> mes("Pretty useful info, huh?")
    |> mes("Take care, my friend.")
    |> changequest(3114, 3115)
    |> set_char_var(:diamond_edq, 22)
    |> close()
  end

  defp discuss_jewel(ctx, 0) do
    ctx
    |> mes("[Leblo]")
    |> mes("Hm? I'm sorry, but")
    |> mes("I'm pretty busy with")
    |> mes("all my other customers.")
    |> mes("Besides, you don't strike")
    |> mes("me as a jewel seller or")
    |> mes("buyer. Please excuse me...")
    |> close()
  end

  defp discuss_jewel(ctx, 1) do
    {ctx, choice} =
      ctx
      |> mes("[Leblo]")
      |> mes("Oh, hey. Did you")
      |> mes("have any business")
      |> mes("with me today?")
      |> next()
      |> select(["I have a jewel to sell.", "No, not really."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Leblo]")
          |> mes("Oh, yeah? Well then,")
          |> mes("I'm curious now. You")
          |> mes("mind if I take a look?")
          |> next()

        if count_item(ctx, 7725) > 0 do
          ctx
          |> mes("[Leblo]")
          |> mes("Now, what do we ha--")
          |> mes("Oh. I'm sorry, but I just")
          |> mes("can't buy this. I hate to")
          |> mes("break it to you, but I hear")
          |> mes("that thing has an awful curse.")
          |> mes("See what you can do about that!")
          |> set_char_var(:jewel_nd, 2)
          |> close()
        else
          ctx
          |> mes("[Leblo]")
          |> mes("Hmm. The jewel")
          |> mes("you were just")
          |> mes("talking about...")
          |> mes("Did you remember")
          |> mes("to bring it with you?")
          |> close()
        end

      2 ->
        ctx
        |> mes("[Leblo]")
        |> mes("Oh, yeah? Well, that's")
        |> mes("fine too. No skin off")
        |> mes("my nose, that's what")
        |> mes("I always say.")
        |> close()

      _ ->
        ctx
    end
  end

  defp discuss_jewel(ctx, 2) do
    ctx
    |> mes("[Leblo]")
    |> mes("Oh. I'm sorry, but I just")
    |> mes("can't buy this. I hate to")
    |> mes("break it to you, but I hear")
    |> mes("that thing has an awful curse.")
    |> mes("See what you can do about that!")
    |> close()
  end

  defp discuss_jewel(ctx, _) do
    ctx
    |> mes("[Leblo]")
    |> mes("I'm sorry that you're")
    |> mes("the one that currently")
    |> mes("has that jewel. Hopefully,")
    |> mes("the curse is just a rumor...")
    |> mes("But, well, I didn't get this")
    |> mes("old by taking chances...")
    |> close()
  end
end
