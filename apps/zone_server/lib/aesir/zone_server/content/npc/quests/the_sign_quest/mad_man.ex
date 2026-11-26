defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.MadMan do
  @moduledoc """
  Guides adventurers seeking Angrboda's soul through The Sign quest.

  ## Behavior

  - Sells the soul pieces' locations and explanations of the directions.
  - Reminds adventurers how to break the seals and where to take the soul.

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
        map: "niflheim",
        x: 102,
        y: 54,
        dir: 4,
        sprite: 739,
        name: "Mad Man",
        scope: :shared,
        unique_name: "Mad Man#s"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Laichin]")
    progress = get_char_var(ctx, :sign_q, 0)

    cond do
      progress < 82 ->
        greeting(ctx)

      progress < 96 ->
        life_in_niflheim(ctx)

      progress == 96 ->
        offer_directions(ctx)

      progress in 97..100 ->
        offer_explanation(ctx)

      progress < 105 ->
        seal_advice(ctx)

      progress < 150 ->
        soul_advice(ctx)

      progress == 200 ->
        ctx
        |> mes("Whoa...")
        |> mes(".................")
        |> mes("My freakin' head hurts.")
        |> close()

      true ->
        ctx |> mes("Whoa...") |> mes(".................") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx) do
    ctx
    |> mes("What? I look familiar to you?")
    |> mes("Eh, you know what they say.")
    |> mes("Everyone has a lookalike in the")
    |> mes("world somewhere. Am I right")
    |> mes("or am I right?")
    |> close()
  end

  defp life_in_niflheim(ctx) do
    ctx
    |> mes("Niflheim ain't such a bad")
    |> mes("place to live. Sure, Asgard's")
    |> mes("all pretty and stuff, but there's too many rules. In this place, you")
    |> mes("can enjoy a lot more freedom. After you get used to all the stink.")
    |> next()
    |> mes("[Laichin]")
    |> mes("Did I say 'stink?'")
    |> mes("I meant... 'fragrance.'")
    |> mes("Alright, so the gods expelled")
    |> mes("me, but I really oughtta thank")
    |> mes("'em for sending me here!")
    |> next()
    |> mes("[Laichin]")
    |> mes("What's that look for...?")
    |> mes("What, you can't believe")
    |> mes("that someone like me used")
    |> mes(
      "to live in Valhalla? Me neither! They really made a mistake when they put me up to live in Asgard!"
    )
    |> close()
  end

  defp offer_directions(ctx) do
    {ctx, _} =
      ctx
      |> mes("Angrboda...?")
      |> mes("Yeah, yeah!")
      |> mes("I remember hearing something")
      |> mes("about her when I usedta hang")
      |> mes("with the gods up in Asgard.")
      |> next()
      |> mes("[Laichin]")
      |> mes("Yeah, those guys were pretty")
      |> mes(
        "gangster about it. I mean, they took her soul, broke it in four pieces and stashed them in the deepest hole in Midgard!"
      )
      |> next()
      |> mes("[Laichin]")
      |> mes("Sure, she was a giant, but")
      |> mes("they were pretty scared of her.")
      |> mes("All her children ended up to be legendary monsters! Well, I'm")
      |> mes("not sure if Lady Hell counts.")
      |> next()
      |> mes("[Laichin]")
      |> mes("That's pretty harsh.")
      |> mes("I mean, even if you die,")
      |> mes("your soul has no place to")
      |> mes("rest. Angrboda's soul is")
      |> mes("all cut up and stuff!")
      |> next()
      |> select(["So where are the soul pieces again?"])

    {ctx, choice} =
      ctx
      |> mes("[Laichin]")
      |> mes("What...? I just said,")
      |> mes("the deepest underground")
      |> mes("place in Midgard.")
      |> mes("It's a dangerous joint")
      |> mes("protected by gangs")
      |> mes("of monsters.")
      |> next()
      |> mes("[Laichin]")
      |> mes("Wait, you tellin' me")
      |> mes("that you're gonna find")
      |> mes("all of Angrboda's soul?!")
      |> mes("You're crazy! If they end up")
      |> mes("missing, the gods'll know I was")
      |> mes("the one who tipped you off!")
      |> next()
      |> mes("[Laichin]")
      |> mes("If I was gonna risk my soul,")
      |> mes("I'd wanna enjoy the rest of my")
      |> mes("afterlife as my much as I could")
      |> mes("before the gods offed me. Man,")
      |> mes("I'd need at least 40,000 Zeny to even have a decent time...")
      |> next()
      |> select(["Pay Laichin 40,000 Zeny", "Don't pay Laichin."])

    case choice do
      1 -> buy_directions(ctx)
      2 -> ctx |> mes("[Laichin]") |> mes("Huh...?") |> mes("Okay pal.") |> close()
      _ -> ctx
    end
  end

  defp buy_directions(ctx) do
    if zeny(ctx) < 40_000 do
      ctx
      |> mes("[Laichin]")
      |> mes("Hey...")
      |> mes("This is sooo")
      |> mes("not enough money")
      |> mes("for me to enjoy myself")
      |> mes("if my soul ends up getting")
      |> mes("busted by the gods.")
      |> emotion(:hng)
      |> close()
    else
      ctx =
        ctx
        |> mes("[Laichin]")
        |> mes("Now we're talkin'!")
        |> mes("You're a true hero!")
        |> mes("Right, you gotta go to the")
        |> mes("lowest part of Glast Heim to")
        |> mes("find Angrboda's soul pieces.")
        |> next()
        |> set_local(:select_s, Enum.random(1..5))

      case get_local(ctx, :select_s, 0) do
        direction when direction in 1..4 ->
          ctx = ctx |> mes("[Laichin]") |> directions(direction) |> next()
          confirm_directions(ctx)

        _ ->
          ctx |> mes("[Laichin]") |> mes("Heh heh!") |> close()
      end
    end
  end

  defp confirm_directions(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Laichin]")
      |> mes("Her soul pieces are really")
      |> mes(
        "well hidden, so you gotta look around, even if you know the general location. And don't"
      )
      |> mes("tell anyone else about these locations or there'll be trouble.")
      |> next()
      |> select(["I promise.", "What do you mean by big and small?"])

    case choice do
      1 ->
        ctx
        |> mes("[Laichin]")
        |> mes("Alright, kid.")
        |> mes("Have fun!")
        |> finish_directions(:promise)

      2 ->
        buy_explanation(ctx)

      _ ->
        ctx
    end
  end

  defp buy_explanation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Laichin]")
      |> mes("What do I mean by")
      |> mes("big and small? Hey man,")
      |> mes("the answer to that is worth")
      |> mes("at least... 20,000 Zeny.")
      |> mes("If you wanna know,")
      |> mes("cough up the cash!")
      |> next()
      |> select(["Don't pay him.", "Pay him."])

    case choice do
      1 ->
        ctx
        |> mes("[Laichin]")
        |> mes("Fine, fine.")
        |> mes("Just don't come")
        |> mes("crawling back when")
        |> mes("you can't figure out")
        |> mes("where the soul pieces are!")
        |> pay_zeny(40_000)
        |> finish_directions(:decline_explanation)

      2 ->
        if zeny(ctx) < 60_000 do
          not_enough(ctx, true)
        else
          ctx
          |> explain_directions()
          |> pay_zeny(60_000)
          |> finish_directions(:buy_explanation)
        end

      _ ->
        ctx
    end
  end

  defp finish_directions(ctx, choice) do
    case get_local(ctx, :select_s, 0) do
      direction when direction in 1..4 ->
        case choice do
          :promise ->
            ctx |> set_char_var(:sign_q, 96 + direction) |> pay_zeny(40_000) |> close()

          :decline_explanation ->
            ctx |> set_char_var(:sign_q, 96 + direction) |> emotion(:hng) |> close()

          :buy_explanation ->
            ctx |> set_char_var(:sign_q, 100 + direction) |> close()
        end

      _ ->
        case choice do
          :promise ->
            ctx |> mes("[Laichin]") |> mes("Heh heh!") |> close()

          :decline_explanation ->
            ctx |> mes("[Laichin]") |> mes("Hehehehe~") |> close()

          :buy_explanation ->
            ctx |> mes("[Laichin]") |> mes("Eh heh") |> mes("heh heh heh!") |> close()
        end
    end
  end

  defp offer_explanation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Oh yeah, about those")
      |> mes("directions I gave you")
      |> mes("last time? They work, but")
      |> mes("you gotta know what I mean")
      |> mes("by 'big' or 'small' whatever")
      |> mes("o' clock means. That's right... ")
      |> next()
      |> mes("[Laichin]")
      |> mes("Matter of fact, I'll")
      |> mes("tell you all about it.")
      |> mes("Right after you pay me,")
      |> mes("oh, I don't know, ^FF000020,000 zeny^000000.")
      |> next()
      |> select(["Pay him.", "Don't pay him."])

    case choice do
      1 ->
        if zeny(ctx) < 20_000 do
          not_enough(ctx, false)
        else
          ctx = ctx |> explain_directions() |> pay_zeny(20_000)

          case get_char_var(ctx, :sign_q, 0) do
            progress when progress in 97..100 ->
              ctx |> set_char_var(:sign_q, progress + 4) |> close()

            _ ->
              ctx |> mes("[Laichin]") |> mes("Bwahahaha!") |> close()
          end
        end

      2 ->
        ctx
        |> mes("[Laichin]")
        |> mes("Whatever, dude!")
        |> mes("Freakin' cheapskate...")
        |> emotion(:hng)
        |> close()

      _ ->
        ctx
    end
  end

  defp not_enough(ctx, show_emotion) do
    ctx =
      ctx
      |> mes("[Laichin]")
      |> mes("What is this?")
      |> mes("You tryin to welch")
      |> mes("me or somethin'?")

    ctx = if show_emotion, do: emotion(ctx, :hng), else: ctx
    close(ctx)
  end

  defp explain_directions(ctx) do
    ctx
    |> mes("[Laichin]")
    |> mes("Alright, listen up.")
    |> mes("Big, small and very small")
    |> mes("mean the distances from the")
    |> mes("center of the map. So for big,")
    |> mes("I mean look near the border of")
    |> mes("the map. Easy, huh?")
    |> next()
    |> mes("[Laichin]")
    |> mes("When I say small, you")
    |> mes("gotta look in areas closer")
    |> mes("than the borders of the map.")
    |> mes("For very small, you gotta")
    |> mes("look near the center. Got it?")
  end

  defp directions(ctx, 1) do
    ctx
    |> mes("Check out the")
    |> mes("big 1 o' clock,")
    |> mes("big 5 o' clock,")
    |> mes("big 7 o' clock and")
    |> mes("the small 6 o' clock.")
  end

  defp directions(ctx, 2) do
    ctx
    |> mes("Check out the")
    |> mes("big 4 o' clock,")
    |> mes("big 10 o' clock,")
    |> mes("small 6 o' clock and the")
    |> mes("very small 11 o' clock.")
  end

  defp directions(ctx, 3) do
    ctx
    |> mes("Check out the")
    |> mes("big 5 o' clock,")
    |> mes("small 11 o' clock,")
    |> mes("small 6 o' clock and the")
    |> mes("very small 11 o' clock.")
  end

  defp directions(ctx, 4) do
    ctx
    |> mes("Check out the")
    |> mes("big 4 o' clock,")
    |> mes("big 5 o' clock,")
    |> mes("big 10 o' clock and")
    |> mes("the small 11 o' clock.")
  end

  defp directions(ctx, _), do: ctx

  defp seal_advice(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Oh yeah. Uh, I forgot to tell")
      |> mes(
        "you that Angrboda's soul pieces are sealed with the power of the gods. You can't just smash them open."
      )
      |> next()
      |> mes("[Laichin]")
      |> mes("...Or maybe you could.")
      |> mes("Anyway, it'll be better")
      |> mes("if you had a weapon that")
      |> mes("was solid, heavy and powerful.")
      |> next()
      |> mes("[Laichin]")
      |> mes("But yeah, think about")
      |> mes("what it means to break")
      |> mes("a godly seal. Remember there's")
      |> mes("^FF0000some kinda rule^000000 that the gods imposed which you gotta follow")
      |> mes("to release Angrboda's soul.")
      |> next()
      |> mes("[Laichin]")
      |> mes("Ah, right. If you wanna")
      |> mes("try different weapons for")
      |> mes("breaking those seals, make")
      |> mes("sure you got 'em in your")
      |> mes("inventory and that they're")
      |> mes("not equipped, alright?")
      |> next()
      |> select(["Thanks~!", "Where am I supposed to go again?"])

    case choice do
      1 ->
        ctx
        |> mes("[Laichin]")
        |> mes("Oh no...")
        |> mes("Thank you for all")
        |> mes("of this zeny! Money")
        |> mes("might not be able to")
        |> mes("buy happiness, but it")
        |> mes("sure comes real close!")
        |> close()

      2 ->
        repeat_directions(ctx)

      _ ->
        ctx
    end
  end

  defp repeat_directions(ctx) do
    ctx =
      ctx
      |> mes("[Laichin]")
      |> mes("Hey... You gotta")
      |> mes("go to the lowest part")
      |> mes("of Glast Heim to find all")
      |> mes("of Angrboda's soul pieces.")
      |> mes("Once you get there...")
      |> next()
      |> mes("[Laichin]")

    ctx
    |> directions(get_char_var(ctx, :sign_q, 0) - 100)
    |> mes("And break those seals")
    |> mes("in that order, okay?")
    |> next()
    |> mes("[Laichin]")
    |> mes("Big, small and very small")
    |> mes("mean the distances from the")
    |> mes("center of the map. So for big,")
    |> mes("I mean look near the border of")
    |> mes("the map. Easy, huh?")
    |> next()
    |> mes("[Laichin]")
    |> mes("When I say small, you")
    |> mes("gotta look in areas closer")
    |> mes("than the borders of the map.")
    |> mes("For very small, you gotta")
    |> mes("look near the center. Got it?")
    |> close()
  end

  defp soul_advice(ctx) do
    ctx
    |> mes("Dude, Niflheim rocks.")
    |> mes("It's like, a million times")
    |> mes("better than that boring")
    |> mes("old Asgard. Hell yeah!")
    |> next()
    |> mes("[Laichin]")
    |> mes("Eh, I don't even wanna")
    |> mes("know if you manage to")
    |> mes("find all of Angrboda's soul")
    |> mes("pieces, but if you do, don't")
    |> mes("go bringin' close to me. If the")
    |> mes("gods find out you have 'em... ")
    |> next()
    |> mes("[Laichin]")
    |> mes("But for the sake of")
    |> mes("argument, let's say you")
    |> mes("do happen to get them all.")
    |> mes("In that case, you oughta get")
    |> mes("Angrboda's soul to the Queen")
    |> mes("of Hell right away, alright?")
    |> next()
    |> mes("[Laichin]")
    |> mes("Ooh.. But not just any")
    |> mes("yahoo can waltz up to her.")
    |> mes("The best thing would be to")
    |> mes("give it to one of her really")
    |> mes("trusted retainers, I guess.")
    |> mes("Now, who was he again?")
    |> next()
    |> mes("[Laichin]")
    |> mes("I know he's always in")
    |> mes("disguise as some sorta")
    |> mes("really ^666666despressing guy^000000")
    |> mes("and I can't remember his")
    |> mes("name for the life of me, but")
    |> mes("he's around here somewhere...")
    |> close()
  end
end
