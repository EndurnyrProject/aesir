defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.GoohoAhn do
  @moduledoc """
  Gooho Ahn deciphers a secret Z Gang letter.

  ## Behavior

  - Requests materials, decrypts the letter, and advances the investigation.

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
      %{map: "payon", x: 192, y: 176, dir: 3, sprite: 903, name: "Gooho Ahn", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :zdan_edq, 0) do
      12 -> request_materials(ctx)
      13 -> check_materials(ctx)
      14 -> remind_letter(ctx)
      _ -> describe_encryption(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp request_materials(ctx) do
    ctx =
      ctx
      |> mes("[Gooho Ahn]")
      |> mes("Oh, hello")
      |> mes("adventurer.")
      |> mes("Um, was there")
      |> mes("something you wanted?")

    {ctx, choice} =
      ctx
      |> emotion(:question, playerattached(ctx))
      |> next()
      |> select(["Rogue Guild's Decoding Request"])

    case choice do
      1 -> explain_request(ctx)
      _ -> ctx
    end
  end

  defp explain_request(ctx) do
    ctx =
      ctx
      |> mes("[Gooho Ahn]")
      |> mes("Ah, Marybell sent you?")
      |> mes("I see. I've been struggling")
      |> mes("trying to decrypt this letter.")
      |> mes("Did you want to take a look?")
      |> next()
      |> mes("[Gooho Ahn]")
      |> mes("This looks like a piece")
      |> mes("of blank paper, but if you")
      |> mes("add just the right amount")
      |> mes("of heat and light, you can")
      |> mes("read its contents. This is")
      |> mes("some powerful encryption!")

    ctx
    |> emotion(:huk, playerattached(ctx))
    |> next()
    |> mes("[Gooho Ahn]")
    |> mes("So far, I've only decrypted")
    |> mes("just a portion of the letter's")
    |> mes("content. Unfortunately, I ran")
    |> mes("out of the materials I need to")
    |> mes("measure how much light and heat")
    |> mes("I need to unlock this message.")
    |> next()
    |> mes("[Gooho Ahn]")
    |> mes("I'm pretty swamped over")
    |> mes("here, but if you're working")
    |> mes("for Marybell, I don't think")
    |> mes("you'd mind doing a favor")
    |> mes("for me. Would you gather")
    |> mes("the materials I need?")
    |> next()
    |> mes("[Gooho Ahn]")
    |> mes("I need")
    |> mes("^0000FF20 Live Coals^000000,")
    |> mes("^0000FF1 Matchstick^000000,")
    |> mes("^0000FF2 Alcohol^000000, and")
    |> mes("^0000FF10 Burning Hearts^000000.")
    |> next()
    |> mes("[Gooho Ahn]")
    |> mes("Once I have the things")
    |> mes("I need, I should be able")
    |> mes("to decrypt the rest of")
    |> mes("this secret Z Gang letter.")
    |> changequest(3129, 3130)
    |> set_char_var(:zdan_edq, 13)
    |> close()
  end

  defp check_materials(ctx) do
    ctx =
      ctx
      |> mes("[Gooho Ahn]")
      |> mes("So did you bring the")
      |> mes("things I need to measure")
      |> mes("how much light and heat")
      |> mes("I need to reveal the rest")
      |> mes("of this secret Z Gang letter?")
      |> next()

    if count_item(ctx, 7098) > 19 and count_item(ctx, 970) > 1 and
         count_item(ctx, 7035) > 0 and count_item(ctx, 7097) > 9 do
      decipher_letter(ctx)
    else
      missing_materials(ctx)
    end
  end

  defp decipher_letter(ctx) do
    ctx =
      ctx
      |> mes("[Gooho Ahn]")
      |> mes("Oh, good. Thanks a lot.")
      |> mes("Now I should do my part,")
      |> mes("and decrypt the rest of")
      |> mes("this letter. Mm... Just")
      |> mes("give me a second to")
      |> mes("make some adjustments...")
      |> next()
      |> delitem(7098, 20)
      |> delitem(970, 2)
      |> delitem(7035, 1)
      |> delitem(7097, 10)
      |> emotion(:aha)
      |> mes("[Gooho Ahn]")
      |> mes("Oh, what? This language...")
      |> mes("It's ancient! Aegye hasn't")
      |> mes("been used in... centuries.")
      |> mes("I've seen Aegye used in the")
      |> mes("Book of Forbidden Mystery")
      |> mes("before it was stolen.")
      |> next()
      |> mes("[Gooho Ahn]")
      |> mes("There's a legend about")
      |> mes("an ancient civilization that")
      |> mes("set the foundation for our")
      |> mes("modern society. The Aegye")
      |> mes("language was considered")
      |> mes("a subcultural phenomenon.")
      |> next()
      |> mes("[Gooho Ahn]")
      |> mes("Aegye was popular among")
      |> mes("children and rebellious")
      |> mes("teens, but was considered")
      |> mes("vulgar until it entered the")
      |> mes("mainstream. Then, somehow... ")
      |> next()
      |> mes("[Gooho Ahn] ")
      |> mes("Aegye destroyed that")
      |> mes("ancient people's lingual")
      |> mes("system and civilization")
      |> mes("once it was popularized.")
      |> mes("That is why there is strong")
      |> mes("Aegye censorship today.")
      |> next()
      |> mes("[Gooho Ahn] ")
      |> mes("In fact, the existence")
      |> mes("of Aegye is supposed to")
      |> mes("be a huge secret. That")
      |> mes("language is responsible")
      |> mes("for one of the greatest")
      |> mes("disasters of all time.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...............................")
      |> mes("So what's the letter say?")
      |> next()
      |> mes("[Gooho Ahn] ")
      |> mes("Mm... Let me check...")
      |> mes("My knowledge in Aegye")
      |> mes("is very limited, so...")
      |> next()
      |> mes("[Gooho Ahn] ")
      |> mes("^0000ffWeii arr prowd Z G gna^000000")
      |> mes("^0000ffAynoen hwo sspotp uys^000000")
      |> mes("^0000ffwlil eb kckide on htier ssa!^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("What...?")
    |> next()
    |> mes("[Gooho Ahn] ")
    |> mes("That's the nature")
    |> mes("of Aegye: it is chaotic,")
    |> mes("and barely legible!")
    |> mes("Regardless, this letter")
    |> mes("is invaluable as research")
    |> mes("material for my studies.")
    |> next()
    |> mes("[Gooho Ahn] ")
    |> mes("It will be enough")
    |> mes("for Marybell if you")
    |> mes("deliver the message to")
    |> mes("her verbatim. Listen")
    |> mes("to me carefully, and")
    |> mes("maybe write this down.")
    |> next()
    |> mes("[Gooho Ahn] ")
    |> mes("^0000ffWeii arr prowd Z G gna^000000")
    |> mes("^0000ffAynoen hwo sspotp uys^000000")
    |> mes("^0000ffwlil eb kckide on htier ssa!^000000")
    |> changequest(3130, 3131)
    |> set_char_var(:zdan_edq, 14)
    |> close()
  end

  defp missing_materials(ctx) do
    ctx
    |> mes("[Gooho Ahn]")
    |> mes("Please hurry!")
    |> mes("I'm sure Marybell is")
    |> mes("waiting to learn the")
    |> mes("whereabouts of the Z Gang,")
    |> mes("and this letter might have")
    |> mes("a clue. Oh, and remember...")
    |> next()
    |> mes("[Gooho Ahn] ")
    |> mes("I need")
    |> mes("^0000FF20 Live Coals^000000,")
    |> mes("^0000FF1 Matchstick^000000,")
    |> mes("^0000FF2 Alcohol^000000, and")
    |> mes("^0000FF10 Burning Hearts^000000.")
    |> next()
    |> mes("[Gooho Ahn]")
    |> mes("Once I have the things")
    |> mes("I need, I should be able")
    |> mes("to decrypt the rest of")
    |> mes("this secret Z Gang letter.")
    |> close()
  end

  defp remind_letter(ctx) do
    ctx
    |> mes("[Gooho Ahn] ")
    |> mes("Please tell Marybell")
    |> mes("the contents of the")
    |> mes("Z Gang's letter so that")
    |> mes("I can keep the original")
    |> mes("document for research purposes.")
    |> next()
    |> mes("[Gooho Ahn] ")
    |> mes("^0000ffWeii arr prowd Z G gna^000000")
    |> mes("^0000ffAynoen hwo sspotp uys^000000")
    |> mes("^0000ffwlil eb kckide on htier ssa!^000000")
    |> close()
  end

  defp describe_encryption(ctx) do
    ctx
    |> mes("[Gooho Ahn] ")
    |> mes("Encryption is the art of")
    |> mes("hiding truth in layers of")
    |> mes("secrecy. My specialty is")
    |> mes("in unraveling the truth")
    |> mes("by breaking encryption.")
    |> close()
  end
end
