defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.BuenderHikeman do
  @moduledoc """
  Buender Hikeman, an old miner of Einbech, mistakes the adventurer for Shinokas, the friend who
  betrayed him.

  ## Behavior

  - Starts the Murder Quest by recounting the mine collapse that killed his friends.
  - Advances the quest once he confronts the adventurer as Shinokas and collapses.
  - Once the misunderstanding is cleared, the adventurer may tell him about Shinokas's death to
    complete the quest for base and job experience scaled by base level and game mode.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 165,
        y: 105,
        dir: 7,
        sprite: 847,
        name: "Buender Hikeman",
        scope: :shared,
        unique_name: "Buender Hikeman#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = cutin(ctx, "ein_hicman", 2)

    case get_char_var(ctx, :Shinokas_Quest, 0) do
      0 ->
        accuse_stranger(ctx)

      1 ->
        swear_vengeance(ctx)

      2 ->
        ctx
        |> mes("^3355FFIt'd be best")
        |> mes("to avoid aggravating")
        |> mes("the old man for now.^000000")
        |> close()
        |> cutin("ein_hicman", 255)

      10 ->
        clear_misunderstanding(ctx)

      _ ->
        ctx
        |> mes("^3355FFHikeman is dozing")
        |> mes("off in his chair. Judging")
        |> mes("from the look of discomfort")
        |> mes("on his face, he seems to be")
        |> mes("having a nightmare.")
        |> cutin("ein_hicman", 255)
        |> close()
    end
  end

  defp accuse_stranger(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Buender Hikeman]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("...")
      |> mes("......")
      |> mes("......You...")
      |> emotion(:question, playerattached(ctx))
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("...")
      |> mes("......")
      |> mes("......You...")
      |> mes("......Stop it...")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("...")
      |> mes("......")
      |> mes("......You...")
      |> mes("......Stop it...")
      |> mes("...You ^FF0000bastard^000000!")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("RaaaaAAAARGHHH!!")
      |> next()
      |> mes("^3355FFThe old man seems")
      |> mes("slightly irked at seeing")
      |> mes("you. Unfortunately, his")
      |> mes("screaming and rambling")
      |> mes("is totally incoherent.^000000")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("It ^FF0000IS^000000 you!")
      |> mes("You're responsible!")
      |> mes("You've taken everything")
      |> mes("away from me!!")
      |> next()
      |> select(["'What are you talking about?'", "Ignore Him."])

    case choice do
      1 ->
        ctx
        |> mes("[Buender Hikeman]")
        |> mes("How dare you...")
        |> mes("How dare you treat ")
        |> mes("after destroying all the")
        |> mes("happiness in my life!")
        |> next()
        |> mes("[Buender Hikeman]")
        |> mes("Damn you...")
        |> mes("How can you have")
        |> mes("the audacity to pretend")
        |> mes("as if nothing happened?!")
        |> mes("^333333*C-cough Cough...*^000000")
        |> next()
        |> recount_discovery()

      2 ->
        ctx
        |> mes("[Buender Hikeman]")
        |> mes("W...wait!")
        |> mes("I said wait!")
        |> mes("^333333*Cough!*^000000")
        |> close()
        |> cutin("ein_hicman", 255)

      _ ->
        ctx
    end
  end

  defp recount_discovery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Buender Hikeman]")
      |> mes("Are you so evil to")
      |> mes("just shallowly forget")
      |> mes("what you've done to our")
      |> mes("lives? Did you already")
      |> mes("forget what you did")
      |> mes("here in Einbech?!")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("It was such a long")
      |> mes("time ago, but I'll never")
      |> mes("forget. This town was")
      |> mes("small, but full of folk")
      |> mes("with warm hearts...")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("Me, Khartophe, Anuto,")
      |> mes("Maskharundt... All of")
      |> mes("us were friends hired")
      |> mes("by that big businessman")
      |> mes("to dig up ores in the mine.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("And then there")
      |> mes("was you! All of us")
      |> mes("put together made the")
      |> mes("greatest mining team!")
      |> mes("That was, until, we")
      |> mes("discovered ^FF0000it^000000.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("Yes...")
      |> mes("The mysterious ore")
      |> mes("that dazzled with a")
      |> mes("magnificent light.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("But we should have known")
      |> mes("that the ^3131FFUngoliant^000000 would")
      |> mes("be around that ore. We")
      |> mes("should have realized")
      |> mes("the danger...")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("We reported our findings")
      |> mes("to our employer, and then")
      |> mes("the ore just disappeared. He")
      |> mes("must have sent it somewhere,")
      |> mes("it was none of our business.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("Then life was back")
      |> mes("to normal for a while.")
      |> mes("But one day you yelled")
      |> mes("to us that you had found")
      |> mes("another special, mysterious")
      |> mes("ore in the mines.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("But when we came")
      |> mes("over to check the hole")
      |> mes("you dug up, you know")
      |> mes("what we found...?!")
      |> next()
      |> select(["Ungoliant?", "A mysterious ore, right?", "Nothing...?"])

    case choice do
      choice when choice in [1, 2] ->
        ctx
        |> mes("[Buender Hikeman]")
        |> mes("Don't you remember")
        |> mes("what happened? What")
        |> mes("you did to us at that time?!")
        |> next()
        |> recount_collapse()

      3 ->
        ctx
        |> mes("[Buender Hikeman]")
        |> mes("Yes...")
        |> mes("Nothing.")
        |> next()
        |> recount_collapse()

      _ ->
        ctx
    end
  end

  defp recount_collapse(ctx) do
    ctx
    |> mes("[Buender Hikeman]")
    |> mes("There was nothing")
    |> mes("inside the hole!")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Then you pointed to")
    |> mes("the wall behind us and")
    |> mes("screamed that Ungoliant")
    |> mes("was coming! In our panic")
    |> mes("we started to dig our way out!")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes(
      "I remember that the expression on your face seemed so strange. I had thought you looked sad, but now I'm sure you were consumed by greed! We trusted you and you betrayed us! ^FFFFFFspace^000000"
    )
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("When we finally smashed")
    |> mes("down that last wall, everything")
    |> mes("starting to fall around us. We")
    |> mes("were the only two to survive")
    |> mes("that tunnel collapse.")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Then I learned...")
    |> mes("You planned it all along.")
    |> setquest(2071)
    |> set_char_var(:Shinokas_Quest, 1)
    |> close()
    |> cutin("ein_hicman", 255)
  end

  defp swear_vengeance(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Buender Hikeman]")
      |> mes("Bastard!")
      |> mes("I'm sick of")
      |> mes("your lies!")
      |> next()
      |> select(["I'm not who you think!", "How did you survive the accident?"])

    case choice do
      1 ->
        ctx
        |> mes("[Buender Hikeman]")
        |> mes("Ha...!")
        |> mes("Do you think")
        |> mes("I'd so easily")
        |> mes("forget the face")
        |> mes("of the person who")
        |> mes("shattered my life?!")
        |> next()
        |> recount_survival()

      2 ->
        recount_survival(ctx)

      _ ->
        ctx
    end
  end

  defp recount_survival(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("When I came to,")
      |> mes("I was lying on my")
      |> mes("stomach in the ruins")
      |> mes("of that dark tunnel.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("And I found...")
      |> mes("You know what I found.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("^333333*Cough Cough*^000000")
      |> mes("The corpses of my friends!")
      |> mes("Khartophe, Anuto, Maskharundt!")
      |> mes("Great men and my best friends.")
      |> mes("But where were you?!")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("Your body was nowhere")
      |> mes("to be found. I searched")
      |> mes("the tunnel and finally")
      |> mes("climbed outside where")
      |> mes("I was found unconscious.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("I was so stupid.")
      |> mes("It was because of")
      |> mes("that ore! You killed our")
      |> mes("friends and destroyed")
      |> mes("my life for that thing!")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("And now...")
      |> mes("You come out of")
      |> mes("hiding and show up.")
      |> mes("What do you want of")
      |> mes("me? What more can")
      |> mes("you possibly take away?!")
      |> next()
      |> select(["I'm not who you think I am!", "I'd like to apologize."])

    case choice do
      1 ->
        ctx
        |> mes("[Buender Hikeman]")
        |> mes("Quit lying!")
        |> mes("You've stirred up")
        |> mes("my hatred by showing")
        |> mes("up again! I've never")
        |> mes("forgotten that day!")
        |> next()
        |> attack_and_collapse()

      2 ->
        ctx
        |> mes("[Buender Hikeman]")
        |> mes("Ha ha...")
        |> mes("Apologize?")
        |> mes("The harm is")
        |> mes("already done...")
        |> next()
        |> attack_and_collapse()

      _ ->
        ctx
    end
  end

  defp attack_and_collapse(ctx) do
    ctx
    |> mes("[Buender Hikeman]")
    |> mes("It's too late")
    |> mes("for you now. For")
    |> mes("the sake of my friends,")
    |> mes("I'll have my vengeance!")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Prepare to die!")
    |> mes("^3131FFShinokas^000000!!!!")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("...!")
    |> mes("^333333*Cough! Cough!*^000000")
    |> mes("Noooo! N-not now...")
    |> mes("^333333*Cough! Cough!*^000000")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("...")
    |> mes("I better")
    |> mes("get away")
    |> mes("from him!")
    |> next()
    |> mes("^3355FFYou ran away from Hikeman")
    |> mes("as he collapsed on the ground.")
    |> mes("It wouldn't be a good idea to")
    |> mes("provoke the old man anymore,")
    |> mes("intentionally or not.^000000")
    |> changequest(2071, 2072)
    |> set_char_var(:Shinokas_Quest, 2)
    |> close()
    |> cutin("ein_hicman", 255)
  end

  defp clear_misunderstanding(ctx) do
    player = "[#{char_name(ctx, 0)}]"

    {ctx, choice} =
      ctx
      |> mes("^3355FFHikeman is dozing")
      |> mes("off in his chair. Judging")
      |> mes("from the look of discomfort")
      |> mes("on his face, he seems to be")
      |> mes("having a nightmare.")
      |> next()
      |> mes(player)
      |> mes("Excuse me...")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("Huh...?")
      |> mes(".........!!")
      |> mes("Hahahahaha!")
      |> mes("Come back for")
      |> mes("your beating,")
      |> mes("eh, Shinokas?!")
      |> next()
      |> mes(player)
      |> mes("Look...!")
      |> mes("I'm not Shinokas,")
      |> mes("okay? How can you")
      |> mes("forget what he looks")
      |> mes("like or how old he is?")
      |> mes("I'm way younger!")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("What...?")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("................")
      |> emotion(:surprise)
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("Uhhhh......")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("Huh.")
      |> next()
      |> insist_on_being_female(player)
      |> mes("[Buender Hikeman]")
      |> mes("It seems...")
      |> mes("I've made a")
      |> mes("huge mistake.")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes(
        "Ever since the accident, people have said that I haven't been the same. Maybe they're right."
      )
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("I keep making the same")
      |> mes("mistakes, so maybe they're")
      |> mes("right about me getting senile.")
      |> mes("Did you come just to clear")
      |> mes("up this misunderstanding?")
      |> next()
      |> mes(player)
      |> mes("Um...")
      |> mes("Actually...")
      |> next()
      |> select(["Tell Hikeman about Shinokas's death.", "Don't notify Hikeman."])

    case choice do
      1 -> tell_of_shinokas_death(ctx, player)
      2 -> keep_silent(ctx, player)
      _ -> ctx
    end
  end

  defp insist_on_being_female(ctx, player) do
    if sex(ctx) == 0 do
      ctx
      |> mes(player)
      |> mes("And...")
      |> mes("I'm a cute girl!")
      |> mes("Shinokas is male")
      |> mes("and kind of...")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("What...?")
      |> mes("IMPOSSIBLE!")
      |> next()
      |> mes(player)
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Buender Hikeman]")
      |> mes("...")
      |> mes("......")
      |> next()
    else
      ctx
    end
  end

  defp tell_of_shinokas_death(ctx, player) do
    ctx
    |> mes(player)
    |> mes("Shinokas died")
    |> mes("a while ago in")
    |> mes("Einbroch.")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Wh-what...?")
    |> next()
    |> mes(player)
    |> mes("Shinokas was killed by")
    |> mes("some men. He thinks they")
    |> mes("may have been the ones")
    |> mes("who hired you guys. In the")
    |> mes("end, he was betrayed too...")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("I...")
    |> mes("I see...")
    |> next()
    |> mes(player)
    |> mes("Shinokas may have")
    |> mes("gotten some money,")
    |> mes("but he spent the rest")
    |> mes("of his life in hiding,")
    |> mes("being hunted down.")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Nothing's left.")
    |> mes("I've got nothing")
    |> mes("to look foward to.")
    |> mes("I was living only to")
    |> mes("avenge my friends...")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Please...")
    |> mes("Just go back to")
    |> mes("wherever you came")
    |> mes("from. Leave me alone...")
    |> next()
    |> mes(player)
    |> mes("...")
    |> next()
    |> mes(player)
    |> mes("^333333Did Hikeman really want")
    |> mes("revenge on Shinokas or did")
    |> mes("he want to hear him out since")
    |> mes("they used to be close friends?^000000")
    |> next()
    |> mes(player)
    |> mes("^333333If I mention that")
    |> mes("what they found was")
    |> mes("the Ymir Heart Piece,")
    |> mes("Hikeman might end up")
    |> mes("getting hunted down, so")
    |> mes("I better not say anything.^000000")
    |> next()
    |> mes(player)
    |> mes("^333333Why are those men")
    |> mes("so obsessed with that")
    |> mes("Ymir Heart Piece? Is it")
    |> mes("really worth this kind of")
    |> mes("cruelty? Whoever they are,")
    |> mes("their intentions can't be good.")
    |> close()
    |> cutin("ein_hicman", 255)
    |> completequest(2078)
    |> set_char_var(:Shinokas_Quest, 11)
    |> grant_quest_exp()
  end

  defp grant_quest_exp(ctx) do
    {base_exp, job_exp} =
      if Rathena.truthy?(checkre(ctx, 3)) do
        cond do
          base_level(ctx) < 70 -> {30_000, 30_000}
          base_level(ctx) < 80 -> {40_000, 40_000}
          base_level(ctx) < 90 -> {70_000, 70_000}
          true -> {90_000, 90_000}
        end
      else
        cond do
          base_level(ctx) < 70 -> {100_000, 80_000}
          base_level(ctx) < 80 -> {300_000, 100_000}
          base_level(ctx) < 90 -> {500_000, 300_000}
          true -> {700_000, 500_000}
        end
      end

    getexp(ctx, base_exp, job_exp)
  end

  defp keep_silent(ctx, player) do
    ctx
    |> mes(player)
    |> mes("Yeah...")
    |> mes("That' right.")
    |> mes("I wanted to clear up")
    |> mes("this misunderstanding")
    |> mes("so you could calm down,")
    |> mes("even if it's just a little bit.")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Well, you don't have")
    |> mes("to worry so much about")
    |> mes("my stress. I find that the")
    |> mes("winds that pass through")
    |> mes("this town to be very relaxing.")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Each time the wind")
    |> mes("blows by, my vision blurs,")
    |> mes("my memories haze and all")
    |> mes("of my hatred just drifts away.")
    |> next()
    |> mes("[Buender Hikeman]")
    |> mes("Without the wind, I'd only")
    |> mes("have my hatred towards ^FF0000him^000000.")
    |> mes("Maybe it's my only reason for")
    |> mes("living and maybe I'm lonely,")
    |> mes("but it's too late to feel")
    |> mes("sorry for myself now.")
    |> close()
    |> cutin("ein_hicman", 255)
  end
end
