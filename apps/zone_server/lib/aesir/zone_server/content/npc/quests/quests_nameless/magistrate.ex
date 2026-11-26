defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Magistrate do
  @moduledoc """
  The magistrate discusses an investigation into smugglers.

  ## Behavior

  - His responses and disclosures follow the player’s investigation progress.

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
        map: "ve_in",
        x: 78,
        y: 314,
        dir: 5,
        sprite: 945,
        name: "Magistrate",
        scope: :shared,
        unique_name: "Magistrate#Aru"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :aru_monas, 0)

    cond do
      progress < 8 -> troubled(ctx)
      progress == 8 -> introduce(ctx)
      progress == 9 -> barred(ctx)
      progress == 10 -> ask_about_smugglers(ctx)
      progress < 13 -> warning(ctx)
      progress == 13 -> explain_investigation(ctx)
      true -> frustrated(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp troubled(ctx) do
    ctx
    |> mes("[Al Hamad]")
    |> mes("Argh! Why must this")
    |> mes("happen to me, especially")
    |> mes("just when I'm about to")
    |> mes("retire! A-ah! My ulcer...")
    |> mes("Just all of a sudden, it--!")
    |> close()
  end

  defp introduce(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Al Hamad]")
      |> mes("Man, this is probably")
      |> mes("the biggest hassle of my")
      |> mes("career. Why does this have")
      |> mes("to happen now? Retirement")
      |> mes("is so close, yet so far.")
      |> next()
      |> select(["Are you in trouble?"])

    ctx
    |> mes("[Al Hamad]")
    |> mes("Huh? You don't look like")
    |> mes("you're from around here.")
    |> mes("Listen, I appreciate your")
    |> mes("concern, but I'm really not")
    |> mes("comfortable talking to complete")
    |> mes("strangers about my problems.")
    |> set_char_var(:aru_monas, 9)
    |> close()
  end

  defp barred(ctx) do
    ctx
    |> mes("[Al Hamad]")
    |> mes("Unless you've got special")
    |> mes("business here, you're not")
    |> mes("allowed to enter this place.")
    |> mes("We're here to keep the public")
    |> mes("peace, and letting anyone")
    |> mes("in here will cause trouble.")
    |> close()
  end

  defp ask_about_smugglers(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Al Hamad]")
      |> mes("I thought I told you")
      |> mes("that you weren't allowed")
      |> mes("to come in here. Why do")
      |> mes("you keep coming back?")
      |> next()
      |> select(["I'm sorry.", "I want to know about the smugglers."])

    if choice == 1 do
      ctx
      |> mes("[Al Hamad]")
      |> mes("It's fine. Just leave,")
      |> mes("and don't come back")
      |> mes("unless you've got a")
      |> mes("really good reason.")
      |> close()
    else
      ctx
      |> mes("[Al Hamad]")
      |> mes("Hey, how'd you find out")
      |> mes("about the smugglers? Did")
      |> mes("word spread around town?")
      |> mes("Well, I'm sorry, but I can't")
      |> mes("disclose any details about")
      |> mes("an ongoing investigation.")
      |> next()
      |> mes("[Al Hamad]")
      |> mes("^9370DBIf you insist on learning")
      |> mes("more, then you'd need to")
      |> mes("bring me a written order")
      |> mes("from a higher ranking officer.^000000")
      |> mes("Oh, and you're prohibited")
      |> mes("asking anyone else, so behave.")
      |> set_char_var(:aru_monas, 11)
      |> close()
    end
  end

  defp warning(ctx) do
    ctx
    |> mes("[Al Hamad]")
    |> mes("I don't blame you for")
    |> mes("being curious, but getting")
    |> mes("involved when you're not")
    |> mes("supposed to will just cause")
    |> mes("trouble. Be careful, got it?")
    |> close()
  end

  defp explain_investigation(ctx) do
    ctx
    |> mes("[Al Hamad]")
    |> mes("Huh, that's weird. You're not")
    |> mes("even a citizen of Arunafeltz,")
    |> mes("but somehow you know such")
    |> mes("a high ranking priest. Alright,")
    |> mes("I guess I can tell you more")
    |> mes("about our investigation.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("I should let you know that")
    |> mes("what I tell you might not be")
    |> mes("worth all that trouble. This")
    |> mes("information probably isn't")
    |> mes("as valuable as you think.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("The smugglers we caught are")
    |> mes("the worst kind of scoundrels:")
    |> mes("they deal in human trafficking, but we caught them this time when they")
    |> mes("were crossing the ocean. Their background info is pretty typical.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("Let's see... They kidnapped")
    |> mes("some man from Comodo.")
    |> mes("That's a place in the southwest")
    |> mes("part of Rune-Midgarts. Anyway,")
    |> mes("the smugglers thought he'd be")
    |> mes("wealthy, so they set a trap.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("They lured him away from his")
    |> mes("guards by sending a woman,")
    |> mes("but when they captured him,")
    |> mes("they found that he was not only")
    |> mes("rich, he was also a high ranked")
    |> mes("official of Rune-Midgarts.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("That's when they got sloppy:")
    |> mes("they were so scared that the")
    |> mes("kingdom's troops might pursue")
    |> mes("them that they crossed the")
    |> mes("ocean that we patrol. That's")
    |> mes("where we caught them.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("What I don't understand is")
    |> mes("why they were so scared.")
    |> mes("I mean, they mainly deal")
    |> mes("in human trafficking so...")
    |> mes("Kidnapping an official isn't")
    |> mes("that big a difference, is it?")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("We contacted the temple,")
    |> mes("and reported the smugglers,")
    |> mes("our investigation, and the")
    |> mes("high ranking man from the")
    |> mes("Rune-Midgarts kingdom.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("Then, some people from")
    |> mes("the temple interrupted our")
    |> mes("investigation, took away the")
    |> mes("smugglers before we finished")
    |> mes("our interrogations, and we")
    |> mes("haven't seen them since.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("I asked an acquaintance that")
    |> mes("works at the temple, but he")
    |> mes("doesn't know what's going")
    |> mes("on either. The ^32CD32Rune-Midgarts")
    |> mes("official^000000 has gone missing too.")
    |> mes("It's all very frustrating.")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("That happens to be all")
    |> mes("I know. Does this mean")
    |> mes("we have to capture the")
    |> mes("smugglers again? I don't")
    |> mes("know what's going on...")
    |> set_char_var(:aru_monas, 14)
    |> next()
    |> mes("[Al Hamad]")
    |> mes("Even if I could make headway")
    |> mes("into the investigation, I've")
    |> mes("been ordered to stop by upper")
    |> mes("management. It looks like")
    |> mes("this case is more trouble")
    |> mes("than it's worth to them?")
    |> next()
    |> mes("[Al Hamad]")
    |> mes("I don't want to be involved")
    |> mes("in this anymore. I should be")
    |> mes("retired already! If you want to")
    |> mes("learn more, your only choice")
    |> mes("would be to find out on your")
    |> mes("own. Fat chance, right?")
    |> close()
  end

  defp frustrated(ctx) do
    ctx
    |> mes("[Al Hamad]")
    |> mes("I've suffered enough")
    |> mes("already! Why can't this")
    |> mes("case just be done?!")
    |> close()
  end
end
