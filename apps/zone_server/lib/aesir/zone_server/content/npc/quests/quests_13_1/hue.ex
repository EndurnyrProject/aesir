defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Hue do
  @moduledoc """
  Hue is the Schwarzwald researcher who signs the meeting invitation and restores the damaged report.

  ## Behavior

  - Turns away overloaded players and warns visitors away until `ep13_ryu` or `ep13_start`
    exceeds 99; unmatched chapter steps also receive a restricted-area warning.
  - At step 4 takes the Meeting Invitation; at step 5 has a one-in-four chance to read it,
    then signs and returns it only if asked, advancing to step 6.
  - At step 15 requests restoration materials for the soaked report (quest 8202 to 8203).
    Step 16 consumes the report, Fan, Old Frying Pan, Flame Stone and Chinese Ink; step 17
    has a one-in-four chance to return the Neat Report (8203 to 8204), otherwise asks to wait.
  - Steps 18 to 23 discuss the report and meeting aftermath. At step 24 sends the Neat Report
    to Ryosen with a Pineapple Jubilee (8208 to 8209); steps 25 to 99 repeat the delivery request.
  - Above step 99 trades two Furs for one Pineapple Jubilee, refusing the trade when the player
    already carries five or more Jubilees.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 247,
        y: 255,
        dir: 1,
        sprite: 868,
        name: "Hue",
        scope: :shared,
        unique_name: "Hue#ep131_rhea02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @invitation 6036
  @soaked_report 6037
  @neat_report 6038
  @fan 7262
  @old_frying_pan 7031
  @flame_stone 7521
  @chinese_ink 1024
  @pineapple_jubilee 12_320
  @fur 6020

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      overloaded?(ctx) -> overloaded(ctx)
      in_chapter?(ctx) -> at_step(ctx, get_char_var(ctx, :ep13_1_rhea, 0))
      true -> warns_visitors(ctx)
    end
  end

  defp overloaded?(ctx) do
    checkweight(ctx, [{1201, 1}]) == 0 or
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 3500
  end

  defp in_chapter?(ctx) do
    get_char_var(ctx, :ep13_ryu, 0) > 99 or get_char_var(ctx, :ep13_start, 0) > 99
  end

  defp at_step(ctx, step) do
    cond do
      step < 4 -> warns_adventurers(ctx)
      step == 4 -> receives_invitation(ctx)
      step == 5 -> reads_invitation(ctx)
      step == 6 -> warns_about_hansenne(ctx)
      step == 15 -> requests_restoration_materials(ctx)
      step == 16 -> collects_restoration_materials(ctx)
      step == 17 -> restores_report(ctx)
      step == 18 -> awaits_report_delivery(ctx)
      step == 19 -> prepares_for_meeting(ctx)
      step == 20 -> fears_the_meeting_room(ctx)
      step > 20 and step < 24 -> thinks_about_the_meeting(ctx)
      step == 24 -> sends_apology(ctx)
      step > 24 and step < 100 -> awaits_apology_delivery(ctx)
      step > 99 -> trades_for_fur(ctx)
      true -> restricted_area(ctx)
    end
  end

  defp overloaded(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("How come you've got so much to carry?")
    |> mes("Are you perhaps on training or something?")
    |> close()
  end

  defp warns_visitors(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("What are you doing here?")
    |> next()
    |> mes("[Hue]")
    |> mes("Don't walk around this place without thinking.")
    |> mes("After all, it'll be you who'd be in trouble.")
    |> close()
  end

  defp warns_adventurers(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("What is it you want?")
    |> next()
    |> mes("[Hue]")
    |> mes("Don't walk around this place without thinking.")
    |> mes("After all, it'll be you who'd be in trouble.")
    |> close()
  end

  defp restricted_area(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("Don't walk around this area. It's restricted.")
    |> close()
  end

  defp receives_invitation(ctx) do
    if count_item(ctx, @invitation) > 0 do
      {ctx, choice} =
        ctx
        |> mes("[Hue]")
        |> mes("What is it you want?")
        |> next()
        |> mes("[Hue]")
        |> mes("You can't just come and go around as you please here. This is a restricted area.")
        |> next()
        |> select(["Sorry...", "I came to show you this."])

      if choice == 1 do
        ctx
        |> mes("[Hue]")
        |> mes("You're just helpless, aren't you?")
        |> close()
      else
        takes_invitation(ctx)
      end
    else
      ctx
      |> mes("[Hue]")
      |> mes("What are you doing here?")
      |> next()
      |> mes("[Hue]")
      |> mes("You can't go around this place as you want. This is a restricted area.")
      |> close()
    end
  end

  defp takes_invitation(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("What's that?")
    |> next()
    |> mes("[Hue]")
    |> mes("...An invitation to the meeting... ?")
    |> next()
    |> mes("[Hue]")
    |> mes("Haha. You expect me to accept this?")
    |> mes("As always, scheduling things as they want, report to us to accept it...")
    |> next()
    |> mes("[Hue]")
    |> mes("I can't think of any other words to describe them, except for this word: RUDE!")
    |> next()
    |> mes("[Hue]")
    |> mes(
      "Never ever asking for our opinion and always delivering things through some strangers... By the way, no offense..."
    )
    |> next()
    |> mes("[Hue]")
    |> mes(
      "THey don't ever take the official route! Rune-Midgartish way of reporting! Very unprofessional!"
    )
    |> next()
    |> mes("[Hue]")
    |> mes("Anyway, what is this meeting about?")
    |> mes("Give it to me. I should read it at least.")
    |> next()
    |> mes("[Hue]")
    |> mes(
      "You should have some Sand chips while I'm reading this. Don't expect any taste, it's from Arunafeltz."
    )
    |> delitem(@invitation, 1)
    |> set_char_var(:ep13_1_rhea, 5)
    |> close()
  end

  defp reads_invitation(ctx) do
    ctx = set_local(ctx, :shu_agree00, Enum.random(1..4))

    case get_local(ctx, :shu_agree00, 0) do
      2 ->
        discusses_invitation(ctx)

      3 ->
        ctx
        |> mes("[Hue]")
        |> mes("Come on, what's the hurry?")
        |> mes("Wait a few more minutes, I didn't finish reading it!")
        |> close()

      _ ->
        ctx
        |> mes("[Hue]")
        |> mes(
          "You should have some Sand chips while I'm reading this. Don't expect any taste, it's from Arunafeltz."
        )
        |> close()
    end
  end

  defp discusses_invitation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hue]")
      |> mes("...Meeting Schedule, on the Xth day, from hh:mm to hh:mm...")
      |> mes("Location... Rune-Midgarts' camp...")
      |> mes("Ha! I knew it. Rune-Midgarts' camp again!")
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Objectives... to report on the researching progress of tracking Satan Morocc and the Ash-Vacuum!"
      )
      |> next()
      |> mes("[Hue]")
      |> mes("Having some time to get to know each other??? Haaaaa!")
      |> next()
      |> mes("[Hue]")
      |> mes("Well, thank you for entertaining me. You should tell Ryosen that.")
      |> next()
      |> select(["Ok, I will.", "Please sign the invitation."])

    if choice == 1 do
      ctx
      |> mes("[Hue]")
      |> mes(
        "Well, you should also tell him that I think he's very talented in settin up comedy. Hahaha."
      )
      |> close()
    else
      signs_invitation(ctx)
    end
  end

  defp signs_invitation(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("... Sign this thing???")
    |> next()
    |> mes("[Hue]")
    |> mes("You mean this meeting's for real???")
    |> next()
    |> mes("[Hue]")
    |> mes("Oh my!")
    |> mes("I have never seen an official invitation to be this stupid-looking!")
    |> next()
    |> mes(
      "- Hue got so furious and pressed the pen so hard that the ball point got pushed in. Then he threw the document after signing it. -"
    )
    |> next()
    |> mes("[Hue]")
    |> mes(
      "Well, at least I respect that Ryosen hasn't forgotten the reporting order. So, you're off to Arunafeltz now?"
    )
    |> next()
    |> mes("[Hue]")
    |> mes(
      "You'll experience some hard time talking to Hansenne... It'll be like testing your patience."
    )
    |> mes("Good luck!")
    |> set_char_var(:ep13_1_rhea, 6)
    |> give_item(@invitation, 1)
    |> close()
  end

  defp warns_about_hansenne(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes(
      "I'm not sure if everyone from Arunafeltz is like him, but, it'll be like testing your patience to get Hansenne to read this thing."
    )
    |> mes("You can trust me on that one. Good luck.")
    |> close()
  end

  defp requests_restoration_materials(ctx) do
    if count_item(ctx, @soaked_report) > 0 do
      ctx
      |> mes("[Hue]")
      |> mes("What is this stupid looking pile of documents?")
      |> next()
      |> mes("[Hue]")
      |> mes("Is this the file Ryosen requested from Hansenne??? The one which is all ruined...?")
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Ha! Tsk,tsk! Is this some kind of joke?! Who'd manage the files like this? I'd never know!"
      )
      |> next()
      |> mes("[Hue]")
      |> mes("Whew... I can't even stand looking at it! Oh just, give it to me!")
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Too bad I'm not in Schwarzwald. I could use our document restoring machine back at home... Ugh! Now I gotta do everything manually."
      )
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Hmmm. It's completely soaked. I Should dry this thing first and iron these crumples. Then, I should restore the texts."
      )
      |> next()
      |> mes("[Hue]")
      |> mes(
        "I need some materials. You gotta help me on this. I need ^0000ff1 Fan, 1 Old Frying Pan, 1 Flame Stone, 1 Chinese Ink^000000."
      )
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Hey, hey... don't look at me like that. I know you're not delighted to do these things but think about it, what about me? Why should I restore this garbage?"
      )
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Listen, sometimes, we've got to do things we don't like in order to get things accomplished."
      )
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Just don't gorget that the file will be restored as fast as you prepare those things for me."
      )
      |> set_char_var(:ep13_1_rhea, 16)
      |> changequest(8202, 8203)
      |> close()
    else
      ctx
      |> mes("[Hue]")
      |> mes("I wonder if the preparation for the meeting's going ok.")
      |> next()
      |> mes("[Hue]")
      |> mes(
        "I heard Ryosen say that the file he requested from Hansenne is all ruined. I hope I dont get involved in that trouble."
      )
      |> close()
    end
  end

  defp collects_restoration_materials(ctx) do
    if count_item(ctx, @soaked_report) > 0 and count_item(ctx, @fan) > 0 and
         count_item(ctx, @old_frying_pan) > 0 and count_item(ctx, @flame_stone) > 0 and
         count_item(ctx, @chinese_ink) > 0 do
      ctx
      |> mes("[Hue]")
      |> mes("Impressive. That was fast enough.")
      |> next()
      |> mes("[Hue]")
      |> mes("Give them to me.")
      |> mes("I have no time to waste.")
      |> next()
      |> mes("[Hue]")
      |> mes("Could you please sit there and wait for me while I restore this file?")
      |> delitem(@soaked_report, 1)
      |> delitem(@fan, 1)
      |> delitem(@old_frying_pan, 1)
      |> delitem(@flame_stone, 1)
      |> delitem(@chinese_ink, 1)
      |> set_char_var(:ep13_1_rhea, 17)
      |> close()
    else
      ctx
      |> mes("[Hue]")
      |> mes(
        "Hmmm. It's completely soaked. I Should dry this thing first and iron these crumples. Then, I should restore the texts."
      )
      |> next()
      |> mes("[Hue]")
      |> mes(
        "I need some materials. You gotta help me on this. I need ^0000ff1 Fan, 1 Old Frying Pan, 1 Flame Stone, 1 Chinese Ink^000000."
      )
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Just don't gorget that the file will be restored as fast as you prepare those things for me."
      )
      |> close()
    end
  end

  defp restores_report(ctx) do
    if Enum.random(1..4) == 2 do
      ctx
      |> mes("[Hue]")
      |> mes("There!")
      |> next()
      |> mes("[Hue]")
      |> mes(
        "The binding was too loose, so I re-arranged and bound the file all over again. This is how the true official document should look like. I really think they should learn how to arrange files."
      )
      |> next()
      |> mes("[Hue]")
      |> mes("Please, deliver this file before it's too late. The meeting's gonna begin soon.")
      |> set_char_var(:ep13_1_rhea, 18)
      |> give_item(@neat_report, 1)
      |> changequest(8203, 8204)
      |> close()
    else
      ctx
      |> mes("[Hue]")
      |> mes("Hey, stop pushing me.")
      |> next()
      |> mes("[Hue]")
      |> mes(
        "I have to be extra careful with this kind of work, ok? Can't you sit quietly over there? Take a nap or something."
      )
      |> close()
    end
  end

  defp awaits_report_delivery(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes(
      "The binding was too loose, so I re-arranged and bound the file all over again. This is how the true official document should look like. I really think they should learn how to arrange files."
    )
    |> next()
    |> mes("[Hue]")
    |> mes("Please, deliver this file before it's too late. The meeting's gonna begin soon.")
    |> close()
  end

  defp prepares_for_meeting(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("Well, finally... It's time for the meeting.")
    |> next()
    |> mes("[Hue]")
    |> mes("Like it or not... I should go in.")
    |> close()
  end

  defp fears_the_meeting_room(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("..................")
    |> next()
    |> mes("[Hue]")
    |> mes(".....Ittt....Is... it still there... ?")
    |> close()
  end

  defp thinks_about_the_meeting(ctx) do
    ctx
    |> mes("- Looks like he's thinking about something... very seriously. -")
    |> close()
  end

  defp sends_apology(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("I just decided I can't stay like this.")
    |> next()
    |> mes("[Hue]")
    |> mes("I couldn't confess the truth when Hansenne said he ruined the cake instead of me.")
    |> next()
    |> mes("[Hue]")
    |> mes(
      "I was so bewildered that I lost the chance to say anything... but... I was such a coward to admit that I was the one who caused the trouble."
    )
    |> next()
    |> mes("[Hue]")
    |> mes("I must apologize.")
    |> mes("But then...")
    |> next()
    |> mes("[Hue]")
    |> mes("Oh, I'm so embarrassed to see him face to face. Or.. how about...")
    |> next()
    |> mes("[Hue]")
    |> mes(
      "Here, this is the Rune-Midgarts' report I took with me when everything went messy in the meeting room. Could you please give this to Ryosen?"
    )
    |> next()
    |> mes("[Hue]")
    |> mes("I'm sorry to ask you this but...")
    |> mes("Could you? For this, I'll give you some Schwarzwald's Pineapple Jubilee.")
    |> next()
    |> mes("[Hue]")
    |> mes("Please give this report to Ryosen.")
    |> mes("Thank you.")
    |> set_char_var(:ep13_1_rhea, 25)
    |> give_item(@neat_report, 1)
    |> give_item(@pineapple_jubilee, 1)
    |> changequest(8208, 8209)
    |> close()
  end

  defp awaits_apology_delivery(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("Oh, I'm so embarrassed to see him face to face. Or.. how about...")
    |> next()
    |> mes("[Hue]")
    |> mes(
      "Here, this is the Rune-Midgarts' report I took with me when everything went messy in the meeting room. Could you please give this to Ryosen?"
    )
    |> next()
    |> mes("[Hue]")
    |> mes("I'm sorry to ask you this but...")
    |> mes("Could you?")
    |> close()
  end

  defp trades_for_fur(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hue]")
      |> mes("Ah, hello!")
      |> next()
      |> mes("[Hue]")
      |> mes("If it weren't for you, we wouldn't be able to get along at all.")
      |> mes("I don't know how to thank you!")
      |> next()
      |> mes("[Hue]")
      |> mes("Have you ever seen something called, ^0000ffFur^000000 ?")
      |> mes(
        "I hear you can get it from the monsters called 'Tatacho' and 'Hillsrion' in the fields."
      )
      |> next()
      |> mes("[Hue]")
      |> mes("Could you bring ^0000ffFur^000000 if you get some? I'm not asking it for free.")
      |> mes(
        "I'll give you my Pineapple Jubilee from Schwarzwald, if you bring me ^0000ff2 Furs^000000."
      )
      |> next()
      |> select([
        "I don't have any, right now.",
        "Oh, I'll give you Fur."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Hue]")
        |> mes("Alright, you don't have any.")
        |> next()
        |> mes("[Hue]")
        |> mes("Please give me some when you get some.")
        |> close()

      2 ->
        offers_exchange(ctx)

      _ ->
        ctx
    end
  end

  defp offers_exchange(ctx) do
    if count_item(ctx, @pineapple_jubilee) > 4 do
      ctx
      |> mes("[Hue]")
      |> mes("Ah, oh my.")
      |> next()
      |> mes("[Hue]")
      |> mes("You already have the Pineapple Jubilee from Schwarzwald!")
      |> next()
      |> mes("[Hue]")
      |> mes(
        "I think you should drin that thing fast. Otherwise, all the ice will melt and it'll taste like some kinda medicine!"
      )
      |> close()
    else
      ctx
      |> mes("[Hue]")
      |> mes("Ah, are you sure you want to exchange?")
      |> next()
      |> confirms_exchange()
    end
  end

  defp confirms_exchange(ctx) do
    if count_item(ctx, @fur) > 1 do
      {ctx, choice} =
        ctx
        |> mes("[Hue]")
        |> mes("Oh, so it's the thing called, Fur??")
        |> next()
        |> mes("[Hue]")
        |> mes("Are you sure you want to exchange this for my Pineapple Jubilee?")
        |> next()
        |> select(["No way.", "Sure."])

      if choice == 1 do
        ctx
        |> mes("[Hue]")
        |> mes("Ahhhhh...")
        |> next()
        |> mes("[Hue]")
        |> mes("Come back any time if you change your mind.")
        |> close()
      else
        exchanges_fur(ctx)
      end
    else
      ctx
      |> mes("[Hue]")
      |> mes("Well, I don't think you have any Fur.")
      |> next()
      |> mes("[Hue]")
      |> mes("Please come back if you find any Fur.")
      |> close()
    end
  end

  defp exchanges_fur(ctx) do
    ctx
    |> mes("[Hue]")
    |> mes("Thank you so much.")
    |> next()
    |> mes("[Hue]")
    |> mes(
      "I always needed this because the weather here is colder then I expected. I'm sure this will keep me warm."
    )
    |> delitem(@fur, 2)
    |> give_item(@pineapple_jubilee, 1)
    |> close()
  end
end
