defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Snorren17559 do
  @moduledoc """
  Snorren waits outside the Sapha prison, worried about his missing friend Ogen and the
  captured Laphine.

  ## Behavior

  - Speaks gibberish unless the player wears the Ring of the Ancient Wise King.
  - Advances the Two Tribes quest: offers to interpret, asks for a cure, and takes every
    Yggdrasil Berry once the player brings more than five.
  - Rewards the player with Manuk Coins once Ogen's fate is known, then gives stage-based
    dialog.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "man_in01",
        x: 175,
        y: 59,
        dir: 5,
        sprite: 454,
        name: "Snorren",
        scope: :shared,
        unique_name: "Snorren#ep13_13"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 2}]) == 0 ->
        ctx
        |> mes("Wait a moment!!")
        |> mes("You have too many items.")
        |> mes("You can't receive this.")
        |> mes("Lighten your weight and")
        |> mes("try again.")
        |> close()

      is_equipped(ctx, 2782) != 1 ->
        ctx
        |> mes("[Snorren]")
        |> mes("Ids ad?")
        |> mes("Ns ai dha si asd!")
        |> mes("Ms dfaa sd a.")
        |> close()

      true ->
        talk_quest(ctx, get_char_var(ctx, :ep13_mdrama, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_quest(ctx, 11) do
    {ctx, choice} =
      ctx
      |> mes("He seems anxious as he wanders back and forth..")
      |> mes("Is he the guard of this prison?")
      |> next()
      |> mes("[Snorren]")
      |> mes(".. Argh.. Why not?!")
      |> mes("What a blockhead...")
      |> mes("Hmm?")
      |> mes("Who are you?!")
      |> mes("How could an outsider be here...?")
      |> next()
      |> select(["About the Captured Fairy.", "What is this place?"])

    case choice do
      1 -> captured_fairy(ctx)
      2 -> about_prison(ctx)
      _ -> ctx
    end
  end

  defp talk_quest(ctx, 12) do
    {ctx, _} =
      ctx
      |> mes("[Snorren]")
      |> mes("Umm.. Hold on a sec...")
      |> mes("Luik. It's me. Snorren.")
      |> next()
      |> mes("[Voice through the door]")
      |> mes("Ah, I told you it's not possible Snorren!")
      |> mes("I can only put you in a cell for one night!")
      |> next()
      |> mes("[Snorren]")
      |> mes("Yikes-! Luik, It's not that!")
      |> mes("I brought someone who would interpret that fairy's words!")
      |> mes("till, Can't I come in?")
      |> next()
      |> mes("[Luik's Voice]")
      |> mes(
        "Shut up! Anyway, we have more things to worry about. This Laphine, we need to treat her wounds..."
      )
      |> next()
      |> mes("[Luik's Voice]")
      |> mes("Her body is completely different from ours. What should we do?")
      |> mes("Hey, Snorren! Bring me anything. Anything like herbs!")
      |> next()
      |> mes("[Snorren]")
      |> mes("Herbs? Is her condition that bad?")
      |> mes("Can't we fix her with bradium?")
      |> mes("Oh right, She's not Sapha, ey?")
      |> next()
      |> select(["Nothing gets past you..."])

    ctx
    |> mes("[Snorren]")
    |> mes("Do you have anything on your mind?")
    |> next()
    |> mes(player_header(ctx))
    |> mes("She's a Laphine, right? Then we should ask a Laphine about it...")
    |> mes("Like what we need to treat her...")
    |> mes("I can take care of it.")
    |> next()
    |> mes("[Snorren]")
    |> mes("Really?")
    |> mes("Then hurry up and bring something back...")
    |> mes("We will wait.")
    |> next()
    |> mes(player_header(ctx))
    |> mes("(I think I have no choice but to go back and ask Arc....)")
    |> set_char_var(:ep13_mdrama, 13)
    |> changequest(7061, 7062)
    |> close()
  end

  defp talk_quest(ctx, stage) when stage in 13..16 do
    ctx
    |> mes("[Snorren]")
    |> mes("Hurry up and go find a way to cure this Laphine...")
    |> mes("Then Luik might let us in.")
    |> close()
  end

  defp talk_quest(ctx, 17) do
    if count_item(ctx, 607) > 5 do
      ctx =
        ctx
        |> mes("[Snorren]")
        |> mes("Did you find a cure?")
        |> mes("This.. is one strange looking fruit.")
        |> mes("I saw this fruit from time to time, but never thought this would be a cure..?")
        |> next()
        |> mes("[Snorren]")
        |> mes("I will take everything you've brought with you!")

      ctx
      |> delitem(607, count_item(ctx, 607))
      |> set_char_var(:ep13_mdrama, 18)
      |> next()
      |> mes("[Snorren]")
      |> mes("Now, Let's go inside!")
      |> close()
    else
      ctx
      |> mes(player_header(ctx))
      |> mes("Hmm...this won't be enough....")
      |> mes("I would need at least 6~7 of these...")
      |> next()
      |> mes("[Snorren]")
      |> mes("Is something wrong?")
      |> next()
      |> mes(player_header(ctx))
      |> mes("Huh? Ah, I think we would need more than what I've brought here... I'll be back.")
      |> close()
    end
  end

  defp talk_quest(ctx, 18) do
    ctx
    |> mes("[Snorren]")
    |> mes("I already told Luik everything about you...")
    |> mes("Let's go inside.")
    |> close()
  end

  defp talk_quest(ctx, stage) when stage in [19, 20, 22] do
    ctx
    |> mes("[Snorren]")
    |> mes("I've been waiting for you...")
    |> mes("Let's make haste.")
    |> close()
  end

  defp talk_quest(ctx, 21) do
    ctx
    |> mes("[Snorren]")
    |> mes("I'm really confused now...Should I believe your story or not.")
    |> mes("If it is true that cave really exists and Ogen is hurt...")
    |> close()
  end

  defp talk_quest(ctx, 23) do
    ctx
    |> mes("[Snorren]")
    |> mes("The approximate location is...")
    |> mes("Huge Roots of a tree. Got it.")
    |> mes("You go ahead first. I will stop by at a refinery and be right after you.")
    |> next()
    |> mes("[Snorren]")
    |> mes("Since that place is Laphine's territory, I will go quitely so they won't notice me.")
    |> mes("You just go on ahead, I will be right behind you.")
    |> close()
  end

  defp talk_quest(ctx, 24) do
    ctx
    |> mes("[Snorren]")
    |> mes("You are back. .. Luik wanted me to tell you this...")
    |> mes("Terra, that Laphine, is free now.")
    |> next()
    |> mes("[Snorren]")
    |> mes("We are tired of fighting. We didn't even want to start...")
    |> mes("And we saw her true intention before everything else.")
    |> next()
    |> mes("[Snorren]")
    |> mes("Go and check if Terra went back to her home safely...")
    |> mes("Ogen... He went back to Mother Nature.")
    |> next()
    |> mes("[Snorren]")
    |> mes("I really don't think what Ogen did was the right thing to do...")
    |> mes("But that was... Ogen...")
    |> next()
    |> mes("[Snorren]")
    |> mes("Forgive me, I'm a bit depressed...")
    |> mes("I'd rather just rest here.")
    |> mes("I really appreciate what you've done.")
    |> next()
    |> mes("[Snorren]")
    |> mes("Come back anytime...")
    |> mes("Ok?")
    |> set_char_var(:ep13_mdrama, 25)
    |> give_item(6080, 15)
    |> changequest(7069, 7070)
    |> close()
  end

  defp talk_quest(ctx, stage) when stage > 24 do
    ctx
    |> mes("[Snorren]")
    |> mes("What do you think of this muffler?")
    |> mes("This belonged to Ogen...")
    |> mes("Does it look good on me?")
    |> close()
  end

  defp talk_quest(ctx, _stage) do
    ctx
    |> mes("[Snorren]")
    |> mes("Outsiders shouldn't be here without permission.")
    |> mes("Please get out of here.")
    |> close()
  end

  defp captured_fairy(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Snorren]")
      |> mes("How does an outsider like you know that?")
      |> mes("And..? What? How can you understand what I'm saying?")
      |> next()
      |> mes("[Snorren]")
      |> mes("Helloo...?")
      |> mes("Can you understand the words coming out of my mouth?")
      |> next()
      |> mes("- I show the ring to Snorren. -")
      |> next()
      |> mes("[Snorren]")
      |> mes("Aha! Now I understand...")
      |> mes(
        "That's amazing. a ring capable of interpreting between different languages... and you were able to come all the way here."
      )
      |> next()
      |> mes("[Snorren]")
      |> mes("I heard there are outsiders helping our people.")
      |> mes("You must be one of them!")
      |> next()
      |> mes("[Snorren]")
      |> mes("But where did you hear about that Fairy?")
      |> mes("Frankly, I want to have a word with that Fairy.")
      |> mes("But I don't understand their language.")
      |> next()
      |> select(["Why do you want to talk to her?", "Do you need an interpreter?"])

    case choice do
      1 ->
        missing_friend(ctx)

      2 ->
        ctx
        |> mes("[Snorren]")
        |> mes("An interpreter? Certainly!")
        |> mes("But I can't just do it arbitrarily...")
        |> mes("The reason why I want to have a word with that fairy, I mean Laphine...")
        |> next()
        |> missing_friend()

      _ ->
        ctx
    end
  end

  defp missing_friend(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Snorren]")
      |> mes("I... want to find out if she's got anything to do with my friend...")
      |> next()
      |> select(["Your friend?"])

    {ctx, choice} =
      ctx
      |> mes("[Snorren]")
      |> mes("Yeah. Ogen is missing.")
      |> mes(
        "He said he was curious about the area you are living in and went to check it out. How foolish of him."
      )
      |> next()
      |> mes("[Snorren]")
      |> mes("And he never came back.")
      |> mes("After quite a while, that fairy came.")
      |> next()
      |> mes("[Snorren]")
      |> mes("I don't know what guts she had to just fly into our territory.")
      |> mes("That fairy just kept on yelling 'a bradium!' 'a bradium!'")
      |> next()
      |> mes("[Snorren]")
      |> mes(
        "Our village's vigilantes are saying that fairy is affected by the power of bradium and went crazy."
      )
      |> mes("That's what Laphine are all like!")
      |> next()
      |> mes("[Snorren]")
      |> mes("They just try to make accesories out of the ore which is our source of life.")
      |> mes("They collect anything that possesses magical power.")
      |> next()
      |> mes(player_header(ctx))
      |> mes("You should calm down a bit... Tell me about that captured Laphine.")
      |> next()
      |> mes("[Snorren]")
      |> mes("Right, I'm sorry.")
      |> mes(
        "Anyways, shortly after Ogen went missing the fairy appears... this is too suspicious..."
      )
      |> mes("and that fairy was severely wounded too.")
      |> next()
      |> mes("[Snorren]")
      |> mes("I think...")
      |> next()
      |> mes("[Snorren]")
      |> mes("That fairy attacked Ogen as he was trying to peek on your camp.")
      |> mes(
        "And she was drawn by Ogen's bradium and came all the way here to find more bradium!"
      )
      |> next()
      |> select(["That could be right...", "I don't see it that way..."])

    case choice do
      1 ->
        ctx
        |> mes(player_header(ctx))
        |> mes("But does that Ore called bradium really possess an overwhelming magical power?")
        |> mes("It didn't seem like that...")
        |> next()
        |> mes("[Snorren]")
        |> mes("Really? But, we Sapha can't live without bradium.")
        |> mes("This war with the Laphine... is to protect the bradium from them...")
        |> next()
        |> mes(player_header(ctx))
        |> mes("I see...")
        |> mes("Your people and their people are fighting over the bradium...")
        |> next()
        |> offer_interpreter()

      2 ->
        ctx
        |> mes("[Snorren]")
        |> mes("Is... Is that so?")
        |> mes("Then how do you see this situation?")
        |> next()
        |> mes(player_header(ctx))
        |> mes("It just occurred to me...")
        |> mes("It's like some kind of forbidden area...")
        |> next()
        |> offer_interpreter()

      _ ->
        ctx
    end
  end

  defp offer_interpreter(ctx) do
    ctx
    |> mes(player_header(ctx))
    |> mes("Anyhow, You are going to ask that fairy about Ogen, right?")
    |> mes("If that's the case, I could interpret between you two...")
    |> next()
    |> mes("[Snorren]")
    |> mes("Yeah?!")
    |> mes("Then just wait here for a sec!")
    |> mes("I will go and ask Luik about this!")
    |> set_char_var(:ep13_mdrama, 12)
    |> close()
  end

  defp about_prison(ctx) do
    ctx
    |> mes("[Snorren]")
    |> mes("Uh, Ah~!")
    |> mes("This is a prison.")
    |> mes("You need to obey the rules to keep a peaceful group life.")
    |> next()
    |> mes("[Snorren]")
    |> mes("This is where people who break the rules are kept overnight.")
    |> next()
    |> mes("[Snorren]")
    |> mes("Oh. I'm not one of them.")
    |> mes("I just have some business here.")
    |> mes("Snorren is a good Sapha.")
    |> close()
  end

  defp player_header(ctx), do: "[#{char_name(ctx, 0)}]"
end
