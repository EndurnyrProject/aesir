defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.RaggedMan do
  @moduledoc """
  A stranded treasure hunter seeks fare money and shares a lead.

  ## Behavior

  - Offers a treasure lead in exchange for 1,200 zeny.
  - Responds to the player’s progress in the treasure hunt.

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
        map: "morocc",
        x: 143,
        y: 63,
        dir: 3,
        sprite: 929,
        name: "Ragged Man",
        scope: :shared,
        unique_name: "Ragged Man#nd"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :treasure_nd, 0) == 0 ->
        {ctx, choice} =
          ctx
          |> mes("[Ragged Man]")
          |> mes("H-hello? Would you help me?")
          |> mes("You'd be saving this poor man's")
          |> mes("life if you would just do me")
          |> mes("this favor. Please...")
          |> next()
          |> select(["How may I help you?", "Ignore Him"])

        case choice do
          1 ->
            hear_treasure_story(ctx)

          2 ->
            ctx
            |> mes("[Ragged Man]")
            |> mes("Please! Please, wait!")
            |> mes("You're an adventurer, aren't")
            |> mes("you? I have some valuable")
            |> mes("information to share if you'd")
            |> mes("just spare me some... Hey!")
            |> mes("Come back! No... I just...")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :treasure_nd, 0) == 1 ->
        {ctx, choice} =
          ctx
          |> mes("[Ragged Man]")
          |> mes("Oh, I remember you.")
          |> mes("You must really want that")
          |> mes("treasure now, do you? Just")
          |> mes("give me 1,200 zeny for me")
          |> mes("to go back home, and I'll")
          |> mes("tell you everything I know.")
          |> next()
          |> select(["Give Money", "Don't Give Money"])

        case choice do
          1 ->
            ctx =
              ctx
              |> mes("[Ragged Man]")
              |> mes("Ah, good choice!")
              |> mes("And thank you so much.")
              |> mes("It'll be great to finally be")
              |> mes("back home in Prontera.")
              |> next()

            if zeny(ctx) < 1200 do
              ctx
              |> mes("[Ragged Man]")
              |> mes("What th--?! This isn't")
              |> mes("enough money for me to go")
              |> mes("back home! Well, just come")
              |> mes("back later once you scrounge")
              |> mes("up the funds. I'll be waiting.")
              |> close()
            else
              ctx
              |> pay_zeny(1200)
              |> mes("[Ragged Man]")
              |> mes("Remember that hidden")
              |> mes("treasure I was looking for?")
              |> mes("There's a rumor that it's")
              |> mes("location has finally been")
              |> mes("confirmed. Why don't you")
              |> mes("try finding it for yourself?")
              |> next()
              |> mes("[Ragged Man]")
              |> mes("I'd rather that it end up in")
              |> mes("he hands of someone like")
              |> mes("you than a rival treasure")
              |> mes("hunter. This hunter that")
              |> mes("stays north in town apparently confirmed the treasure's location.")
              |> next()
              |> mes("[Ragged Man]")
              |> mes("Now, I hear that this guy")
              |> mes("hasn't returned home yet,")
              |> mes("and he still hasn't found")
              |> mes("the treasure. He's probably")
              |> mes("run into a pretty big snag.")
              |> next()
              |> mes("[Ragged Man]")
              |> mes("I doubt that he'll let you")
              |> mes("know the treasure's location")
              |> mes("easily, but who knows? Maybe")
              |> mes("he might slip, and accidentally")
              |> mes("give you some kind of clue.")
              |> set_char_var(:treasure_nd, 2)
              |> close()
            end

          2 ->
            ctx
            |> mes("[Ragged Man]")
            |> mes("Fine, have it your way.")
            |> mes("I admit that I'm a little")
            |> mes("disappointed in you. Aren't")
            |> mes("you adventurers supposed")
            |> mes("to be heroes to the people?")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :treasure_nd, 0) == 2 ->
        ctx
        |> mes("[Ragged Man]")
        |> mes("Oh, you're back?")
        |> mes("Ah, you must be having")
        |> mes("trouble finding that guy")
        |> mes("I was talking about. He's")
        |> mes("just in the northern part of this town. It can't be that hard.")
        |> close()

      get_char_var(ctx, :treasure_nd, 0) > 10 ->
        ctx
        |> mes("[Ragged Man]")
        |> mes("You found the treasure?!")
        |> mes("It... It really exists...")
        |> mes("I'm sorry, it's just been")
        |> mes("my dream to... I feel like")
        |> mes("crying... Oh, God... I don't")
        |> mes("know what this feeling is...")
        |> next()
        |> mes("[Ragged Man]")
        |> mes("I mean... I feel so")
        |> mes("damned happy, but...")
        |> mes("I spent my entire fortune...")
        |> mes("Ruined my whole life just")
        |> mes("to see that treasure...")
        |> close()

      true ->
        ctx
        |> mes("[Ragged Man]")
        |> mes("So how's the treasure")
        |> mes("hunt coming along? I hope")
        |> mes("you have better luck than")
        |> mes("I did. Still, I've got a pretty good feeling that you'll find it.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp hear_treasure_story(ctx) do
    {ctx, response} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Okay, what can I do to help?")
      |> next()
      |> mes("[Ragged Man]")
      |> mes("Oh, thank you so much!")
      |> mes("It feels so good to talk to")
      |> mes("someone after being ignored")
      |> mes("all this time! I might appear to")
      |> mes("be a beggar, but I'm actually a")
      |> mes("treasure hunter from Prontera.")
      |> next()
      |> select(["Umm... So?"])

    case response do
      1 ->
        request_fare(ctx)

      _ ->
        ctx
    end
  end

  defp request_fare(ctx) do
    {ctx, offer} =
      ctx
      |> mes("[Ragged Man]")
      |> mes("I was so sure I could find")
      |> mes("the treasure here in Morocc")
      |> mes("when I first started... I did")
      |> mes("all my research and prep work.")
      |> mes("But after hiring teams of other")
      |> mes("hunters and researchers...")
      |> next()
      |> mes("[Ragged Man]")
      |> mes("I've spent my entire fortune,")
      |> mes("and I'm still not any closer")
      |> mes("to finding that treasure.")
      |> mes("I... I don't even have enough")
      |> mes("money to go back home!")
      |> emotion(:cry)
      |> next()
      |> mes("[Ragged Man]")
      |> mes("Won't you spare some")
      |> mes("money, so that I can finally")
      |> mes("go back home to Prontera?")
      |> next()
      |> select(["Why don't you just walk?", "I can give you some money."])

    case offer do
      1 ->
        ctx
        |> mes("[Ragged Man]")
        |> mes("What? You don't think that")
        |> mes("if I could walk to Prontera,")
        |> mes("I'd have done it already?!")
        |> mes("Why would I even bother to")
        |> mes("beg for money? Fine, I don't")
        |> mes("need your brand of sympathy.")
        |> next()
        |> mes("[Ragged Man]")
        |> mes("You know, I had a hot tip")
        |> mes("that I was going to let you")
        |> mes("in on, but if you don't want")
        |> mes("to share, then neither do I!")
        |> set_char_var(:treasure_nd, 1)
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("[Ragged Man]")
          |> mes("Oh, thank you!")
          |> mes("Anything you can spare,")
          |> mes("I'll gladly appreciate!")
          |> mes("God bless you, bless you!")
          |> next()

        if zeny(ctx) < 1200 do
          ctx
          |> mes("[Ragged Man]")
          |> mes("Umm... Oh, dear...")
          |> mes("You're just as bad off")
          |> mes("as I am. I appreciate it,")
          |> mes("but I can't take your money.")
          |> next()
          |> mes("[Ragged Man]")
          |> mes("It's a shame, really.")
          |> mes("If you had given me 1,200")
          |> mes("zeny, I would have tipped")
          |> mes("you off to something big...")
          |> set_char_var(:treasure_nd, 1)
          |> close()
        else
          ctx
          |> pay_zeny(1200)
          |> mes("[Ragged Man]")
          |> mes("Let's see... I just need")
          |> mes("1,200 zeny. That's enough")
          |> mes("for me to go back home.")
          |> mes("Now, I can't let you just")
          |> mes("give me money and let you")
          |> mes("leave empty handed, can I?")
          |> next()
          |> mes("[Ragged Man]")
          |> mes("Remember that hidden")
          |> mes("treasure I was looking for?")
          |> mes("There's a rumor that it's")
          |> mes("location has finally been")
          |> mes("confirmed. Why don't you")
          |> mes("try finding it for yourself?")
          |> next()
          |> mes("[Ragged Man]")
          |> mes("I'd rather that it end up in")
          |> mes("the hands of someone like")
          |> mes("you than a rival treasure")
          |> mes("hunter. This hunter that")
          |> mes("stays north in town apparently confirmed the treasure's location.")
          |> next()
          |> mes("[Ragged Man]")
          |> mes("Now, I hear that this guy")
          |> mes("hasn't returned home yet,")
          |> mes("and he still hasn't found")
          |> mes("the treasure. He's probably")
          |> mes("run into a pretty bad snag.")
          |> next()
          |> mes("[Ragged Man]")
          |> mes("I doubt that he'll let you")
          |> mes("know the treasure's location")
          |> mes("easily, but who knows? Maybe")
          |> mes("he might slip, and accidentally")
          |> mes("give you some kind of clue.")
          |> set_char_var(:treasure_nd, 2)
          |> close()
        end

      _ ->
        ctx
    end
  end
end
