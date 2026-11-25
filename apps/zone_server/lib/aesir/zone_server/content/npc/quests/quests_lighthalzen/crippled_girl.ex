defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.CrippledGirl do
  @moduledoc """
  Setsu awaits her brother and receives news of his fate.

  ## Behavior

  - Responds to the pendant and the player’s account of her brother.
  - Accepts the pendant as the quest progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in03",
        x: 32,
        y: 162,
        dir: 3,
        sprite: 53,
        name: "Crippled Girl",
        scope: :shared,
        unique_name: "Crippled Girl#li_tre"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_curse, 0) do
      23 -> revisit(ctx)
      24 -> ctx |> mes("[Setsu]") |> mes("...") |> mes("......") |> close()
      25 -> recovered(ctx)
      _ -> greet(ctx)
    end
  end

  defp revisit(ctx) do
    has_pendant = count_item(ctx, 7341) > 0
    ctx = revisit_introduction(ctx)
    if has_pendant, do: return_pendant(ctx), else: missing_pendant(ctx)
  end

  defp revisit_introduction(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hey there, are")
    |> mes("you feeling alright?")
    |> next()
    |> mes("[Crippled Girl]")
    |> mes("Oh, thanks,")
    |> mes("I'm fine. But...")
    |> mes("Have we met before?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Yeah, we did.")
    |> mes("You should know who")
    |> mes("I am by now. Hey, you")
    |> mes("didn't forget, did you?")
    |> next()
    |> mes("[Lady]")
    |> mes("Oh, how do I put this?")
    |> mes("The fever she had for the")
    |> mes("last few days. She's gotten")
    |> mes("better, but she's forgotten")
    |> mes("everything that's happened")
    |> mes("in the past few weeks...")
    |> next()
  end

  defp return_pendant(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh... Oh. I'm so")
    |> mes("sorry. But maybe this")
    |> mes("is for the best? Here,")
    |> mes("I think you should keep")
    |> mes("this pendant, though.")
    |> next()
    |> mes("^3131ffYou place the")
    |> mes("old pendant")
    |> mes("into her hands.^000000")
    |> next()
    |> specialeffect2(:forestlight4)
    |> mes("...............")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[Possessed ", char_name(ctx, 0)), "]"))
    |> mes("^3131FFSetsu, please remember")
    |> mes("that I'd never do anything")
    |> mes("to hurt you. Forgive me for")
    |> mes("leaving you behind. I hope")
    |> mes("that one day we'll meet")
    |> mes("again, little princess.^000000")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[Possessed ", char_name(ctx, 0)), "]"))
    |> mes("^3131FFUntil then, I want")
    |> mes("you to be happy, okay?")
    |> mes("Your brother's always")
    |> mes("gonna be looking out for")
    |> mes("you, one way or another...^000000")
    |> next()
    |> mes("[Setsu]")
    |> mes("My brother's...")
    |> mes("That's my brother's")
    |> mes("voice! Brother!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Eh? What? Whoa...")
    |> mes("What came over me?")
    |> mes("The last thing I reme--")
    |> next()
    |> mes("[Setsu]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Well...")
    |> mes("This is awkward.")
    |> delitem(7341, 1)
    |> set_char_var(:lhz_curse, 24)
    |> close()
  end

  defp missing_pendant(ctx) do
    ctx
    |> mes("^3131ffThis would be a good")
    |> mes("opportunity to give her the...^000000")
    |> close()
  end

  defp recovered(ctx) do
    ctx
    |> mes("[Setsu]")
    |> mes("Excuse me, I can't still")
    |> mes("walk but I don't cry")
    |> mes("anymore. I'm doing my best!")
    |> close()
  end

  defp greet(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Crippled Girl]")
      |> mes("...")
      |> mes("......")
      |> mes("*Sigh...*")
      |> next()
      |> select(["Hello, how are you?"])

    ctx =
      ctx
      |> mes("[Crippled Girl]")
      |> mes("Oh, I'm fine,")
      |> mes("thanks for asking.")
      |> mes("I'm just waiting for")
      |> mes("somebody, that's all.")

    if get_char_var(ctx, :lhz_curse, 0) == 19, do: offer_pendant(ctx), else: close(ctx)
  end

  defp offer_pendant(ctx) do
    {ctx, choice} = ctx |> next() |> select(["Show her the Pendant.", "Okay, have a good day."])

    case choice do
      1 -> ask_about_pendant(ctx)
      2 -> ctx |> mes("[Crippled Girl]") |> mes("Okay,") |> mes("bye-bye...") |> close()
      _ -> ctx
    end
  end

  defp ask_about_pendant(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Um, would you have")
      |> mes("any idea who might")
      |> mes("have owned this pendant?")
      |> next()

    if count_item(ctx, 7341) < 1 do
      ctx |> mes("[Crippled Girl]") |> mes("What are you talking about?") |> close()
    else
      explain_pendant(ctx)
    end
  end

  defp explain_pendant(ctx) do
    ctx =
      ctx
      |> emotion(:surprise)
      |> mes("[Crippled Girl]")
      |> mes("Oh, that's mine!")
      |> mes("I gave it to my big brother")
      |> mes("before he went away on some")
      |> mes("sort of business trip. You must")
      |> mes("be his friend, is that right?")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Actually, um,")
      |> mes("you know what...?")
      |> next()
      |> select(["Brutal Truth", "Break it to her gently"])

    case choice do
      1 -> brutal_truth(ctx)
      2 -> gentle_truth(ctx)
      _ -> ctx
    end
  end

  defp brutal_truth(ctx) do
    ctx
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...So basically, your")
    |> mes("brother's @lhz_ghost, oh right,")
    |> mes("did I mention he was dead?")
    |> mes("Anyway, so he's not alive")
    |> mes("anymore, but his spirit or")
    |> mes("whatever is still around and--")
    |> next()
    |> mes("[Crippled Girl]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Crippled Girl]")
    |> mes("...Dead?")
    |> mes("No! I don't believe you!")
    |> mes("He can't die! He was the")
    |> mes("bravest and the sweetest")
    |> mes("and the-- Leave me alone!")
    |> mes("Oh god, get the hell away!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...")
    |> mes("......")
    |> mes("Sheesh.")
    |> mes("Don't kill the")
    |> mes("messenger.")
    |> set_char_var(:lhz_curse, 20)
    |> close2()
    |> warp("lighthalzen", 322, 323)
  end

  defp gentle_truth(ctx) do
    has_pendant = count_item(ctx, 7341) > 0

    ctx =
      ctx
      |> mes("[Crippled Girl]")
      |> mes("Did you meet my")
      |> mes("big brother...?")
      |> next()
      |> mes("[Crippled Girl]")
      |> mes("My brother is a strong")
      |> mes("person, and I should be")
      |> mes("happy of that, because")
      |> mes("nothing could happen")
      |> mes("to him.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Um... yes. So...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Sure, your big brother must be happy.")
      |> mes("He'll come back sometime.")
      |> mes("You should sleep to be healthy")
      |> mes("once your brother returns.")
      |> next()
      |> mes("[Crippled Girl]")
      |> mes("Yes! I must be okay")
      |> mes("and be able to walk when my")
      |> mes("brother come.")

    if has_pendant, do: offer_comfort(ctx), else: close(ctx)
  end

  defp offer_comfort(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("^3131ffYou place the")
      |> mes("old pendant")
      |> mes("into her hands.^000000")
      |> next()
      |> specialeffect2(:forestlight4)
      |> mes("......")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...............")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[Possessed ", char_name(ctx, 0)), "]"))
      |> mes("^3131FFSetsu, please remember")
      |> mes("that I'd never do anything")
      |> mes("to hurt you. Forgive me for")
      |> mes("leaving you behind. I hope")
      |> mes("that one day we'll meet")
      |> mes("again, little princess.^000000")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[Possessed ", char_name(ctx, 0)), "]"))
      |> mes("^3131FFUntil then, I want")
      |> mes("you to be happy, okay?")
      |> mes("Your brother's always")
      |> mes("gonna be looking out for")
      |> mes("you, one way or another...^000000")
      |> next()
      |> mes("[Setsu]")
      |> mes("My brother's...")
      |> mes("That's my brother's")
      |> mes("voice! Brother!")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Eh? What? Whoa...")
      |> mes("What came over me?")
      |> mes("The last thing I reme--")
      |> next()
      |> mes("^FF0000Tears fall from the")
      |> mes("girl's face, then you...^000000")
      |> next()
      |> select(["Distract her", "Comfort her"])

    case choice do
      1 -> distract(ctx)
      2 -> comfort(ctx)
      _ -> ctx
    end
  end

  defp distract(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh, all of this was a play...")
    |> mes("Y-yes a play, I was practising.")
    |> mes("Ha ha~ Is it okay, isn't it?")
    |> next()
    |> mes("[Setsu]")
    |> mes("Oh, you surprised me!")
    |> mes("Even though I didn't think")
    |> mes("it was really my brother, you know?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Excuse me...")
    |> next()
    |> mes("[Setsu]")
    |> mes("I'll do my best!")
    |> mes("I must be okay when my brother return.")
    |> mes("He'll be very proud of me.")
    |> mes("Heh heh~")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Yes, I'm sure of that.")
    |> delitem(7341, 1)
    |> set_char_var(:lhz_curse, 25)
    |> close()
  end

  defp comfort(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Crying have no use!")
    |> mes("You're a very pretty")
    |> mes("girl to be ruining your")
    |> mes("face with useless tears.")
    |> next()
    |> mes("[Setsu]")
    |> mes("............")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You should do your best")
    |> mes("to be healthy for the time")
    |> mes("your big brother return.")
    |> next()
    |> mes("[Setsu]")
    |> mes("Yes...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Listen, when your brother")
    |> mes("return you'll celebrate in")
    |> mes("a beautiful place.")
    |> next()
    |> mes("[Setsu]")
    |> mes("Really?")
    |> mes("It's a promise then! Heh heh~")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I hope it'll be soon!")
    |> mes("When I return I want you to be")
    |> mes("able to walk. See you soon, then!")
    |> next()
    |> mes("[Setsu]")
    |> mes("I'll try hard!")
    |> delitem(7341, 1)
    |> set_char_var(:lhz_curse, 25)
    |> close()
  end
end
