defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.StrangeGuy do
  @moduledoc """
  Dearles, a gambler in Comodo who runs the craftsmanship test of The Sign quest.

  ## Behavior

  - Before and after his part of the quest he mugs the player: 10,000 zeny when they carry it,
    otherwise 10% HP.
  - Asking him about Metz starts the test; he asks for a 30,000 zeny fee and a meeting between
    19:00 and 22:59.
  - Scores the craft items carried (frames, porcelain, plates, mirror, rose and dolls). Above 10
    points he takes one of each, grants EXP and sends the player to the rhythm test.
  - After the rhythm test he hands over the Part of Star's Sob with EXP, refunding 20,000 zeny on
    a good performance, and lets the player retake the rhythm test later.

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
        map: "cmd_in02",
        x: 88,
        y: 51,
        dir: 4,
        sprite: 806,
        name: "Strange Guy",
        scope: :shared,
        unique_name: "Strange Guy#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @craft_items [
    {734, 1},
    {735, 1},
    {736, 1},
    {7149, 1},
    {747, 2},
    {749, 4},
    {740, 1},
    {741, 1},
    {742, 2},
    {743, 3},
    {752, 3},
    {753, 4},
    {754, 4},
    {750, 7},
    {751, 7}
  ]

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Dearles]")
    sign_q = get_char_var(ctx, :sign_q, 0)

    cond do
      sign_q < 25 -> mug_stranger(ctx)
      sign_q == 25 -> introduce_test(ctx)
      sign_q == 26 -> collect_fee(ctx)
      sign_q == 27 -> night_meeting(ctx)
      sign_q == 28 -> explain_collection(ctx)
      sign_q < 35 -> test_progress(ctx, sign_q)
      sign_q == 97 -> mug_again(ctx)
      sign_q == 98 -> old_acquaintance(ctx)
      true -> test_finished(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp mug_stranger(ctx) do
    ctx = losing_streak(ctx)

    if zeny(ctx) < 10_000 do
      ctx
      |> mes("me. Hah! You are poor!")
      |> emotion(:hng)
      |> mes(
        "It also looks like you're low on cash~! Well, this is what guys like me to do to shameless"
      )
      |> mes("moochers like you!")
      |> percent_heal(hp: -10, sp: 0)
      |> close()
    else
      ctx
      |> mes(
        "me. It also looks like you got zeny to spare! I think I'll help myself and borrow some of your cash!"
      )
      |> mes("^FF0000Yoink!^000000")
      |> pay_zeny(10_000)
      |> specialeffect(:coin)
      |> close()
    end
  end

  defp mug_again(ctx) do
    ctx = losing_streak(ctx)

    if zeny(ctx) < 10_000 do
      ctx
      |> mes(
        "me. It also looks like you're low on cash~! Well, this is what guys like me to do to shameless"
      )
      |> mes("moochers like you!")
      |> emotion(:hng)
      |> percent_heal(hp: -10, sp: 0)
      |> close()
    else
      ctx
      |> mes(
        "me. It also looks like you got zeny to spare! I think I'll help myself and borrow some of your cash!"
      )
      |> mes("^FF0000Yoink!^000000")
      |> mes("Giggle giggle..")
      |> pay_zeny(10_000)
      |> close()
    end
  end

  defp losing_streak(ctx) do
    ctx
    |> lament()
    |> mes("[Dearles]")
    |> mes("Hey, you've got that look")
    |> mes("like you want something from")
  end

  defp lament(ctx) do
    ctx
    |> mes("No...! Damn it,")
    |> mes("not again! When's")
    |> mes("my lucky streak")
    |> mes("gonna start?")
    |> next()
  end

  defp introduce_test(ctx) do
    {ctx, choice} = ctx |> lament() |> select(["Excuse me...", "Just pass by."])

    case choice do
      1 -> ask_about_metz(ctx)
      2 -> broke_gambler(ctx)
      _ -> ctx
    end
  end

  defp ask_about_metz(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dearles]")
      |> mes("What is it?!")
      |> mes("I'm not in the mood")
      |> mes("for chatting with complete")
      |> mes("and total strangers, so")
      |> mes("get to the point~!")
      |> next()
      |> select(["Oh, nothing.", "I'm here for Metz...?"])

    case choice do
      1 -> beat_up_intruder(ctx)
      2 -> demand_fee(ctx)
      _ -> ctx
    end
  end

  defp beat_up_intruder(ctx) do
    ctx
    |> mes("[Dearles]")
    |> mes("Wha...? You bother")
    |> mes("me and make lose this")
    |> mes("game for nothing? For that,")
    |> mes("I'll freakin' beat you to near")
    |> mes("freakin' death! Bam bam bam!")
    |> close2()
    |> percent_heal(hp: -100, sp: 0)
    |> soundeffect("effect\\sign_noise.wav", 1)
    |> percent_heal(hp: -99, sp: 0)
    |> warp("comodo", 122, 100)
  end

  defp demand_fee(ctx) do
    ctx
    |> mes("[Dearles]")
    |> mes("Oh. You're here for")
    |> mes(
      "the Sobbing Starlight, huh? If you wanna take my test, there's *ahem* a fee of 30,000 zeny. So take it or leave it, capish?"
    )
    |> next()
    |> mes("[Dearles]")
    |> mes("I'll have nothing")
    |> mes("to do with you if you")
    |> mes("can't pay up. Just think")
    |> mes("of the fee as a preliminary")
    |> mes("for my test. You know, to")
    |> mes("weed out the riffraff.")
    |> set_char_var(:sign_q, 26)
    |> close()
  end

  defp broke_gambler(ctx) do
    ctx
    |> mes("[Dearles]")
    |> mes("Crap...!")
    |> mes("I'm almost broke!")
    |> mes("But I gotta win all")
    |> mes("my cash back! How can")
    |> mes("I raise more money fast")
    |> mes("without actually working...")
    |> close()
  end

  defp collect_fee(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Eh heh heh~")
      |> mes("Soooooo, did you")
      |> mes("bring the money?")
      |> next()
      |> select(["Here you are...", "Not yet..."])

    case choice do
      1 -> ctx |> mes("[Dearles]") |> mes("Ummm.......") |> pay_fee() |> close()
      2 -> fee_not_ready(ctx)
      _ -> ctx
    end
  end

  defp pay_fee(ctx) do
    if zeny(ctx) < 30_000 do
      ctx
      |> mes("When I say 30,000 zeny,")
      |> mes("I mean 30,000 zeny! I'll let")
      |> mes(
        "you off on account of you looking like you're not smart enough to know how to count. But pull this"
      )
      |> mes("on me again and I'll...!")
    else
      ctx
      |> mes("Heh heh~")
      |> mes("That's thirty grand,")
      |> mes("alright! Okay, come back")
      |> mes("to me tomorrow night and")
      |> mes("we'll start your test...")
      |> set_char_var(:sign_q, 27)
      |> pay_zeny(30_000)
    end
  end

  defp fee_not_ready(ctx) do
    ctx
    |> mes("[Dearles]")
    |> mes("Huh...?")
    |> mes("Alright, but you")
    |> mes("better hurry. I can")
    |> mes("change my mind at")
    |> mes("any time, you know!")
    |> close()
  end

  defp night_meeting(ctx) do
    if gettime(ctx, 3) > 18 and gettime(ctx, 3) < 23 do
      ctx
      |> mes("Nice, you're here")
      |> mes("just in time. Well,")
      |> mes("all that matters is that")
      |> mes("you come during the night.")
      |> next()
      |> mes("[Dearles]")
      |> mes("You're wondering how")
      |> mes("a guy like me is pals with")
      |> mes("Metz, but that's none of your")
      |> mes("business. I guess I gotta keep")
      |> mes("this promise to him, so when")
      |> mes("you're ready, say the word.")
      |> set_char_var(:sign_q, 28)
      |> close()
    else
      ctx
      |> mes("Hey... When I say")
      |> mes("''tomorrow night,'' I mean,")
      |> mes(
        "come and talk to me at nighttime! Don't you know anything about shady dealings?! Pfft! Adventurers..."
      )
      |> close()
    end
  end

  defp explain_collection(ctx) do
    ctx
    |> mes("Alright! I want you to")
    |> mes("bring me a bunch of items!")
    |> mes("Yeah, I know, you're a real")
    |> mes("pro at this, but let me set")
    |> mes("you straight before you blow")
    |> mes("this off as a piece of cake...")
    |> next()
    |> mes("[Dearles]")
    |> mes("I'm not gonna give you an")
    |> mes("exact list of items I want. Oh")
    |> mes("no, what you gotta do is bring")
    |> mes("me artsy crafts. This test is")
    |> mes("gonna judge your appreciation")
    |> mes("for... Craftsmanship~")
    |> next()
    |> mes("[Dearles]")
    |> mes("Since I'm seeing whether")
    |> mes("or not you got good taste,")
    |> mes("variety is the important thing")
    |> mes("here. So don't bring freakin'")
    |> mes("a hundred of the same object.")
    |> mes("Just one of each kind'll do.")
    |> next()
    |> mes("[Dearles]")
    |> mes("What are you")
    |> mes("standin' around")
    |> mes("waiting for? Bring")
    |> mes("those collection items!")
    |> set_char_var(:sign_q, 29)
    |> close()
  end

  defp test_progress(ctx, 29) do
    ctx =
      ctx
      |> mes("Ah, so is this")
      |> mes("the stuff you brought?")
      |> mes("Lemme take a look-see...")

    score = craft_score(ctx)
    ctx = next(ctx)

    cond do
      score > 10 -> pass_collection(ctx)
      score > 0 -> lacking_variety(ctx)
      true -> worthless_junk(ctx)
    end
  end

  defp test_progress(ctx, sign_q) when sign_q in [30, 31] do
    ctx
    |> mes("Hey, you gotta")
    |> mes("finish Part Two of")
    |> mes("my test. I'm gonna send")
    |> mes("you to Lamadin now...")
    |> close2()
    |> warp("cmd_in01", 33, 29)
  end

  defp test_progress(ctx, 32) do
    {ctx, choice} =
      ctx
      |> mes("You failed Part Two,")
      |> mes("the rhythm portion of")
      |> mes("my freakin' test?! If you")
      |> mes("wanna try again, you're")
      |> mes("welcome to another chance...")
      |> next()
      |> select(["Yes.", "Maybe later."])

    case choice do
      1 ->
        ctx
        |> mes("[Dearles]")
        |> mes("Okay...")
        |> mes("Just keep in mind")
        |> mes("that Part Two was ")
        |> mes("supposed to be")
        |> mes("the easy part...")
        |> close2()
        |> warp("cmd_in01", 33, 29)

      2 ->
        ctx
        |> mes("[Dearles]")
        |> mes("What...?")
        |> mes("Alright, but you")
        |> mes("really shouldn't give")
        |> mes("up. I mean, Part Two is")
        |> mes("supposed to be ridiculously")
        |> mes("easy. I made it that way...")
        |> close()

      _ ->
        ctx
    end
  end

  defp test_progress(ctx, 33) do
    ctx
    |> mes("Alright, Lamadin")
    |> mes("tells me you passed.")
    |> mes("Not the best performance,")
    |> mes("but it's good enough.")
    |> next()
    |> hand_over_starlight()
    |> level_exp([300, 700, 1900, 1200, 1700], [3000, 7000, 19_000, 12_000, 17_000])
    |> farewell()
  end

  defp test_progress(ctx, 34) do
    ctx
    |> mes("Lamadin tells me")
    |> mes("you passed. Since you")
    |> mes("did so good, I'm gonna")
    |> mes("give you ^333333some^000000 of your money")
    |> mes("back. Not all, but most of it.")
    |> mes("Isn't that reward enough?")
    |> next()
    |> hand_over_starlight()
    |> credit_zeny(20_000)
    |> level_exp([300, 700, 1000, 1400, 1900], [3000, 7000, 10_000, 14_000, 19_000])
    |> farewell()
  end

  defp craft_score(ctx) do
    Enum.reduce(@craft_items, 0, fn {item_id, points}, score ->
      if Rathena.truthy?(count_item(ctx, item_id)), do: score + points, else: score
    end)
  end

  defp pass_collection(ctx) do
    ctx
    |> mes("[Dearles]")
    |> mes("Nice, nice~")
    |> mes("These'll sell for--")
    |> mes("Er, I'm glad to say")
    |> mes("that you pass for now.")
    |> next()
    |> mes("[Dearles]")
    |> mes("I think you're ready")
    |> mes("for the next step. Now,")
    |> mes("I'm gonna send you to")
    |> mes("Lamadin for Part Two")
    |> mes("of my test. Yeah, I know...")
    |> take_craft_items()
    |> set_char_var(:sign_q, 30)
    |> level_exp([300, 500, 800, 1000, 1300], [3000, 5000, 8000, 10_000, 13_000])
    |> next()
    |> warp("cmd_in01", 33, 29)
  end

  defp take_craft_items(ctx) do
    Enum.reduce(@craft_items, ctx, fn {item_id, _points}, ctx ->
      if Rathena.truthy?(count_item(ctx, item_id)), do: delitem(ctx, item_id, 1), else: ctx
    end)
  end

  defp lacking_variety(ctx) do
    ctx
    |> mes("[Dearles]")
    |> mes("Hmm... Some of this")
    |> mes("stuff looks good, but")
    |> mes("there isn't enough variety")
    |> mes("here that proves your eye for")
    |> mes("craftsmanship. Come back")
    |> mes("with more stuff, alright?")
    |> close()
  end

  defp worthless_junk(ctx) do
    ctx
    |> mes("[Dearles]")
    |> mes("Hmm...")
    |> mes("All the stuff you're")
    |> mes("carrying? Worthless junk!")
    |> mes("Go and find stuff that was")
    |> mes("skillfully crafted, okay?")
    |> next()
    |> mes("[Dearles]")
    |> mes("And by crafts I don't mean")
    |> mes("potions, weapons, equipment,")
    |> mes(
      "none of that. Just think of, well, stuff you'd show off in your rooom and you'll be on the right track. Remember, variety!"
    )
    |> close()
  end

  defp hand_over_starlight(ctx) do
    ctx
    |> mes("[Dearles]")
    |> mes("Alright, take this chunk")
    |> mes("of Sobbing Starlight and")
    |> mes("go find someone named,")
    |> mes("um, ''Bakerlan'' in Alberta.")
    |> set_char_var(:sign_q, 35)
    |> give_item(7177, 1)
  end

  defp farewell(ctx) do
    ctx
    |> next()
    |> mes("[Dearles]")
    |> mes("Well, that's it.")
    |> mes("There's no reason")
    |> mes("for you to ever see")
    |> mes("me again. But yeah,")
    |> mes("good luck with that")
    |> mes("Sobbing Starlight business.")
    |> close()
  end

  defp level_exp(ctx, renewal_exp, pre_renewal_exp) do
    exp_by_level = if Rathena.truthy?(checkre(ctx, 3)), do: renewal_exp, else: pre_renewal_exp
    getexp(ctx, exp_for_level(base_level(ctx), exp_by_level), 0)
  end

  defp exp_for_level(level, [below_60, below_70, below_80, below_90, from_90]) do
    cond do
      level < 60 -> below_60
      level < 70 -> below_70
      level < 80 -> below_80
      level < 90 -> below_90
      true -> from_90
    end
  end

  defp old_acquaintance(ctx) do
    ctx =
      ctx
      |> mes("Whaaaaaaaaaat are")
      |> mes("you doing back here?")

    ctx =
      if zeny(ctx) > 9999 do
        ctx
        |> mes("Fine, since we know each")
        |> mes("other, I'm borrowing some")
        |> mes("cash. You know, for old")
        |> mes("time's sake. ^FF0000Yoink!^000000")
        |> emotion(:kik)
        |> pay_zeny(10_000)
      else
        ctx
        |> mes("I got nothin' for you and")
        |> mes("you obviously have nothing")
        |> mes("for me! Now lemme gamble!")
        |> emotion(:hng)
      end

    close(ctx)
  end

  defp test_finished(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Hey, why are you")
      |> mes("still talkin' to me?")
      |> mes("You finished my test.")
      |> mes("It's over. Not get outta")
      |> mes("here before I jack some")
      |> mes("more of your cash!")
      |> emotion(:kik)
      |> next()
      |> select(["Okay.", "I want to take Part Two again."])

    case choice do
      1 ->
        ctx
        |> mes("[Dearles]")
        |> mes("Fine, fine.")
        |> mes("Geez, why do")
        |> mes("these guys always")
        |> mes("come and bother me?")
        |> emotion(:hng)
        |> close()

      2 ->
        ctx
        |> mes("[Dearles]")
        |> mes("Wha...?")
        |> mes("Part Two")
        |> mes("was really")
        |> mes("that fun? Fine,")
        |> mes("knock yourself out.")
        |> next()
        |> warp("cmd_in01", 33, 29)

      _ ->
        ctx
    end
  end
end
