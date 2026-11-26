defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Historian45126 do
  @moduledoc """
  Historian Rodafrian researches the Geoborg curse and the history of Morocc.

  ## Behavior

  - Receives Karlomoff's report and asks the player to find the lyrics of an old song.
  - Discusses the curse when the player returns and advances the quest based on their choice.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - Fixed the lost-report check: the original `countitem(7342) < 0` can never be true, so it
    is `count_item == 0` here, which shows the lost-report message to players without the report
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 45,
        y: 126,
        dir: 3,
        sprite: 702,
        name: "Historian",
        scope: :shared,
        unique_name: "Historian#prt02"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        too_heavy(ctx)

      true ->
        case get_char_var(ctx, :prt_curse, 0) do
          6 -> receive_report(ctx)
          7 -> ask_name(ctx)
          stage when stage > 7 and stage < 30 -> find_mondo(ctx)
          stage when stage in [30, 55] -> returned_with_lyrics(ctx)
          stage when stage in [31, 40] -> return_to_bamph(ctx)
          56 -> visited_karlomoff(ctx)
          60 -> visit_church(ctx)
          _ -> busy(ctx)
        end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp too_heavy(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp receive_report(ctx) do
    if count_item(ctx, 7342) == 0 do
      ctx
      |> mes("^3355FFYou seem to have lost")
      |> mes("Karlomoff's Report. You")
      |> mes("needed to deliver here to")
      |> mes("one of his colleagues...")
      |> close()
    else
      discuss_report(ctx)
    end
  end

  defp discuss_report(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("Oh, how does this place")
      |> mes("have to be so hot? This")
      |> mes("can't be good for my skin...")
      |> mes("Ooh, I wish I were back home")
      |> mes("in the Schwarzwald Republic~")
      |> emotion(:cry)
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Hello there.")
      |> mes("E-excuse me, but,")
      |> mes("um, may I help you?")
      |> next()
      |> select(["Mr. Karlomoff has sent me."])

    {ctx, choice} =
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("Karlomoff...?")
      |> mes("Him? Alright...")
      |> mes("What did he send")
      |> mes("you to me for?")
      |> next()
      |> mes("^3355FFYou hand Karlomoff's")
      |> mes("report to Rodafrian.^000000")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("A report? What does he")
      |> mes("want to show off this time?")
      |> mes("^333333*Sigh*^000000 Ah well, thanks for")
      |> mes("the trouble. I'll look at it,")
      |> mes("though I'm not expecting")
      |> mes("much if Karlomoff wrote it.")
      |> next()
      |> select(["Ask her about her research", "End conversation"])

    if choice == 1 do
      discuss_research(ctx)
    else
      ctx
      |> mes("[Historian]")
      |> mes("Although I love doing my")
      |> mes("research and uncovering")
      |> mes("new information regarding")
      |> mes("history, I feel a little lonely")
      |> mes("sometimes. Not many people")
      |> mes("share my interests, you know...")
      |> close()
    end
  end

  defp discuss_research(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("Oh, you know about the")
      |> mes("Rekenber Historical Research")
      |> mes("Group? Ah, right. Karlomoff")
      |> mes("must have told you already.")
      |> mes("Currently we're researching")
      |> mes("the Rune-Midgarts Kingdom.")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Now, while I understand the")
      |> mes("value of ancient books and")
      |> mes("records, I think Karlomoff")
      |> mes("relies on them too much.")
      |> mes("I prefer more active research")
      |> mes("in the vein of archaelogy.")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Right now, I'm spending")
      |> mes("time in Morocc to visit the")
      |> mes("Sphinx and Pyramids and see")
      |> mes("if I can excavage some relics.")
      |> mes("Hopefully I can uncover some new historical evidence that way.")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("If you're interested in")
      |> mes("learning more about Morocc's")
      |> mes("history, please go ahead and")
      |> mes("talk to my assistance. He's very passionate about studying this")
      |> mes("town's culture and background.")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Actually, the people of")
      |> mes("Morocc also appreciate their")
      |> mes("town's history, and pass down")
      |> mes("songs about ancient times")
      |> mes("through the generations. Let's")
      |> mes("see, how did that one go?")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("^FF0000*The great serpent*^000000")
      |> mes("^FF0000*swallowed the sea.*^000000")
      |> mes("^FF0000*The eagle of the rainbow*^000000")
      |> mes("^FF0000*swallowed the serpent, and*^000000")
      |> mes("and... and... Um. Oh dear.")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("I can't remember the next")
      |> mes("line! Actually, have you")
      |> mes("heard this song before?")
      |> next()
      |> select(["Yes, I have.", "Yes, but it is different.", "No, sorry."])

    case choice do
      1 -> first_lyric(ctx)
      2 -> sing_song(ctx)
      3 -> ask_for_name(ctx)
      _ -> ctx
    end
  end

  defp first_lyric(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("Oh, that's great!")
      |> mes("Would you provide")
      |> mes("me with the line that")
      |> mes("follows these lyrics?")
      |> next()
      |> mes("^FF0000*The great serpent*^000000")
      |> mes("^FF0000*swallowed the sea.*^000000")
      |> mes("^FF0000*The eagle of the rainbow*^000000")
      |> mes("^FF0000*swallowed the serpent.*^000000")
      |> mes("......................")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"answer$", answer)

    if get_local(ctx, :"answer$", "") == "Then the eagle built its nest." do
      request_name_for_lyrics(ctx)
    else
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("Huh...?")
      |> mes("That doesn't sound")
      |> mes("right at all. Are you sure")
      |> mes("that's the lyric you heard?")
      |> delitem(7342, 1)
      |> set_char_var(:prt_curse, 7)
      |> close()
    end
  end

  defp sing_song(ctx) do
    ctx =
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("What was that?")
      |> mes("The song is different?")
      |> mes("Hmm. Then, would you")
      |> mes("please sing the version")
      |> mes("that you know to me?")
      |> next()
      |> mes("^3355FFYou clear your throat")
      |> mes("and begin to sing the song")
      |> mes("that you heard from Karlomoff.^000000")
      |> next()

    {ctx, lyric} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> input(:string)

    ctx = set_local(ctx, :"line$", lyric)

    ctx =
      if get_local(ctx, :"line$", "") == "The great serpent swallowed the sea." do
        ctx
        |> set_local(:total, get_local(ctx, :total, 0) + 1)
        |> mes("*The great serpent*")
        |> mes("*swallowed the sea.*")
      else
        mes(
          ctx,
          Rathena.concat(Rathena.concat("* ", get_local(ctx, :"line$", "")), "*")
        )
      end

    {ctx, lyric} = input(ctx, :string)
    ctx = set_local(ctx, :"line$", lyric)

    ctx =
      if get_local(ctx, :"line$", "") ==
           "The eagle of the rainbow swallowed the serpent." do
        ctx
        |> set_local(:total, get_local(ctx, :total, 0) + 1)
        |> mes("*The eagle of the rainbow*")
        |> mes("*swallowed the serpent.*")
      else
        mes(
          ctx,
          Rathena.concat(Rathena.concat("*", get_local(ctx, :"line$", "")), "*")
        )
      end

    {ctx, lyric} = input(ctx, :string)
    ctx = set_local(ctx, :"line$", lyric)

    ctx =
      if get_local(ctx, :"line$", "") == "Then the eagle built its nest." do
        ctx
        |> set_local(:total, get_local(ctx, :total, 0) + 1)
        |> mes("*Then the eagle built its nest.*")
      else
        mes(
          ctx,
          Rathena.concat(Rathena.concat("*", get_local(ctx, :"line$", "")), "*")
        )
      end

    {ctx, lyric} = input(ctx, :string)
    ctx = set_local(ctx, :"line$", lyric)

    ctx =
      if get_local(ctx, :"line$", "") == "A nest upon the swallowed sea." do
        ctx
        |> set_local(:total, get_local(ctx, :total, 0) + 1)
        |> mes("*A nest upon the swallowed sea.*")
      else
        mes(
          ctx,
          Rathena.concat(Rathena.concat("*", get_local(ctx, :"line$", "")), "*")
        )
      end

    ctx = next(ctx)

    if get_local(ctx, :total, 0) == 4 do
      request_name_for_lyrics(ctx)
    else
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("Huh...?")
      |> mes("That doesn't sound right")
      |> mes("at all. Are you sure those")
      |> mes("are the lyrics you heard?")
      |> delitem(7342, 1)
      |> set_char_var(:prt_curse, 7)
      |> close()
    end
  end

  defp ask_for_name(ctx) do
    ctx
    |> mes("[Historian Rodafrian]")
    |> mes("............")
    |> mes("........................")
    |> mes("Well then. Would you")
    |> mes("mind if I ask you for")
    |> mes("your name, adventurer?")
    |> give_name(true)
  end

  defp ask_name(ctx) do
    ctx
    |> mes("^3355FFArms folded, Rodafrian")
    |> mes("seems to be deep in thought.")
    |> mes("Then, as if making making")
    |> mes("an important decision, she")
    |> mes("looks directly into your eyes")
    |> mes("and begins to speak.^000000")
    |> next()
    |> mes("[Historian Rodafrian]")
    |> mes("Adventurer...")
    |> mes("I want to know your name.")
    |> give_name(false)
  end

  defp find_mondo(ctx) do
    ctx
    |> mes("[Historian Rodafrian]")
    |> mes("As I recall, Mondo should")
    |> mes("be at Mount Mjolnir, located")
    |> mes("in the northern region of the")
    |> mes("Rune-Midgarts Kingdom. Ask")
    |> mes("him for the lyrics of the song that I can't seem to remember...")
    |> close()
  end

  defp returned_with_lyrics(ctx) do
    ctx =
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("Oh, you've returned.")
      |> mes("Have you met with Mondo")
      |> mes("and figured out the lyrics of")
      |> mes("that song I was looking for?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("^FF0000*The great serpent*^000000")
      |> mes("^FF0000*swallowed the sea.*^000000")
      |> mes("^FF0000*The eagle of the rainbow*^000000")
      |> mes("^FF0000*swallowed the serpent.*^000000")
      |> mes("^FF0000*Then snake scales grew on*^000000")
      |> mes("^FF0000*the eagle, and it slowly died.*^000000")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Oh, yes!")
      |> mes("Yes, that was it! Now")
      |> mes("I remember, thank you")
      |> mes("so much! Ah, back to work...")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("^333333(As a historian, Rodafrian")
      |> mes("might be able to help me in")
      |> mes("investigating the curse of the")
      |> mes("Geoborgs. The priests told me")
      |> mes("not to tell anybody, though.")
      |> mes("Should I take this risk?)^000000")
      |> next()
      |> select(["Tell her about Jormungand's curse", "Don't tell her"])

    if choice == 1 do
      reveal_curse(ctx)
    else
      keep_secret(ctx)
    end
  end

  defp reveal_curse(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou explain everything")
      |> mes("that you have learned to")
      |> mes("Rodafrian, choosing not")
      |> mes("to withhold any secrets.^000000")
      |> emotion(:aha)
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes(".....................!")
      |> emotion(:surprise)
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Thank you for sharing that")
      |> mes("with me. I hope you realize")
      |> mes("how precious that information")
      |> mes("is. I had no idea the royal")
      |> mes("family was keeping that kind")
      |> mes("of secret. Goodness, me...")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("You know, I don't really")
      |> mes("know much about poison, but")
      |> mes("I do know that, aside from our")
      |> mes("own Assassins, there are poison")
      |> mes("experts living in some strange")
      |> mes("land located to the west.")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Anyway, your report about")
      |> mes("the Geoborg family will be")
      |> mes("greatly appreciated by the")
      |> mes("Rekenber Historical Research")
      |> mes("Group. But first, I need to")
      |> mes("finish this Morocc project...")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Anyway, keep this information")
      |> mes("a secret between me and you")
      |> mes("for now. Then, when I reveal the secret curse of the Geoborg royal")
      |> mes("family, I'll finally outshine that Karlomoff! Bwahahahahaha!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("^333333(Drat, she didn't give me")
      |> mes("any help... All I did was")
      |> mes("reveal a huge secret to her")
      |> mes("that she might spread around!")
      |> mes("Oh well, I guess I better head")
      |> mes("back to the priests...)^000000")

    ctx =
      if get_char_var(ctx, :prt_curse, 0) == 30 do
        set_char_var(ctx, :prt_curse, 31)
      else
        set_char_var(ctx, :prt_curse, 60)
      end

    close(ctx)
  end

  defp keep_secret(ctx) do
    ctx =
      ctx
      |> mes("[Historian Rodafrian]")
      |> mes("Oh, let me thank you")
      |> mes("once again for going")
      |> mes("through the trouble of")
      |> mes("getting that lyric for me~")
      |> mes("I put my assistant through")
      |> mes("enough trouble already...")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("I also better not forget")
      |> mes("to go through Karlomoff's")
      |> mes("report. I'll have to have a")
      |> mes("debate with him sooner or")
      |> mes("later, and I really want to")
      |> mes("put that guy in his place!")
      |> next()
      |> mes("^3355FFRodafrian seemed very")
      |> mes("happy and began to read")
      |> mes("through Karlomoff's report.")
      |> mes("For now, it would be best")
      |> mes("to return to Father Bamph.^000000")

    ctx =
      if get_char_var(ctx, :prt_curse, 0) == 30 do
        set_char_var(ctx, :prt_curse, 40)
      else
        set_char_var(ctx, :prt_curse, 56)
      end

    close(ctx)
  end

  defp return_to_bamph(ctx) do
    ctx
    |> mes("^3355FFRodafrian seemed very")
    |> mes("happy and began to read")
    |> mes("through Karlomoff's report.")
    |> mes("For now, it would be best")
    |> mes("to return to Father Bamph.^000000")
    |> close()
  end

  defp visited_karlomoff(ctx) do
    ctx
    |> emotion(:fret)
    |> mes("[Historian Rodafrian]")
    |> mes("I just paid a visit to")
    |> mes("Karlomoff and gave him")
    |> mes("a piece of my mind! I think...")
    |> mes("I think I put him in his place.")
    |> mes("But I can never really tell")
    |> mes("with that sneaky guy...")
    |> close()
  end

  defp visit_church(ctx) do
    ctx
    |> emotion(:fret)
    |> mes("[Historian Rodafrian]")
    |> mes("I just aid a visit to")
    |> mes("Karlomoff and gave him")
    |> mes("a piece of my mind! I think...")
    |> mes("I think I put him in his place.")
    |> mes("But I can never really tell")
    |> mes("with that sneaky guy...")
    |> next()
    |> mes("It doesn't look like")
    |> mes("Rodafrian can offer you")
    |> mes("any more information. For")
    |> mes("now, it would be best to")
    |> mes("go to ^3355FFProntera Church.^000000")
    |> close()
  end

  defp busy(ctx) do
    ctx
    |> mes("[Historian Rodafrian]")
    |> mes("I'm sorry, but I'm")
    |> mes("really very busy with my")
    |> mes("research at the moment.")
    |> mes("Perhaps we can talk later")
    |> mes("once I've completed this?")
    |> close()
  end

  defp request_name_for_lyrics(ctx) do
    ctx
    |> mes("[Historian Rodafrian]")
    |> mes("Really? That makes")
    |> mes("sense, but those lyrics")
    |> mes("sound different than the")
    |> mes("ones I had heard. Hmmmm...")
    |> mes("If you don't mind, would you")
    |> mes("please tell me your name?")
    |> give_name(true)
  end

  defp give_name(ctx, delete_report?) do
    ctx = next(ctx)

    {ctx, _} =
      select(
        ctx,
        String.split(Rathena.concat(Rathena.concat("My name is ", char_name(ctx, 0)), "."), ":")
      )

    ctx = mes(ctx, "[Historian Rodafrian]")

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("Ah ", char_name(ctx, 0)), ", eh?"))
      |> mes("Do you mind if I ask you a favor? I really need to verify the true")
      |> mes("lyrics for this song. However,")
      |> mes("I need to stay here in Morocc")
      |> mes("to complete my research.")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("Would you please find my")
      |> mes("colleague Mondo and ask him")
      |> mes("for this song's lyrics? You can")
      |> mes("find him in the ancient ruins")
      |> mes("in Mount Mjolnir, north in the")
      |> mes("Rune-Midgarts Kingdom.")
      |> next()
      |> mes("[Historian Rodafrian]")
      |> mes("I apologize for asking")
      |> mes("you to do what sounds like")
      |> mes("a silly errand, but I actually")
      |> mes("need to know this song's lyrics")
      |> mes("for the sake of my research...")

    ctx =
      if delete_report? do
        delitem(ctx, 7342, 1)
      else
        ctx
      end

    ctx |> set_char_var(:prt_curse, 8) |> close()
  end
end
