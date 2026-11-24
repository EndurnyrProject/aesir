defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Laura15984 do
  @moduledoc """
  Laura confronts Alex about the excavation.

  ## Behavior

  - The confrontation advances the quest; later visits see the aftermath.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 159,
        y: 84,
        dir: 3,
        sprite: 70,
        name: "Laura",
        scope: :shared,
        unique_name: "Laura#2"
      },
      %{
        map: "hu_in01",
        x: 158,
        y: 84,
        dir: 5,
        sprite: 803,
        name: "Alex",
        scope: :shared,
        unique_name: "Alex#2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :hg_odin, 0)

    cond do
      progress in [22, 23] -> confrontation(ctx)
      progress > 23 -> aftermath(ctx)
      true -> ctx
    end
  end

  defp confrontation(ctx) do
    ctx = cutin(ctx, "hu_laura03.bmp", 2)

    ctx =
      ctx
      |> emotion(:fret, getnpcid(ctx, "Laura#2"))
      |> mes("[Laura]")
      |> mes("Wh-what...?!")
      |> mes("Does this mean")
      |> mes("that everyone has")
      |> mes("had me fooled this")
      |> mes("whole time?! This is")
      |> mes("complete lunacy!")
      |> next()
      |> cutin("hu_alex04.bmp", 0)

    ctx =
      ctx
      |> emotion(:fret, getnpcid(ctx, "Alex#2"))
      |> mes("[Alex]")
      |> mes("What are you talking")
      |> mes("about, you crazy wench?")
      |> mes("You saw the shrine on the")
      |> mes("other side! That's no secret!")
      |> next()
      |> cutin("hu_laura03.bmp", 2)
      |> mes("[Laura]")
      |> mes("I'm not talking about that!")
      |> mes("I saw your brother digging")
      |> mes("everywhere in town in the")
      |> mes("middle of the night!")
      |> next()
      |> cutin("hu_alex04.bmp", 0)
      |> mes("[Alex]")
      |> mes("Lies...!")
      |> mes("Where the hell did")
      |> mes("you get that idea?")
      |> mes("What makes you think")
      |> mes("there are artifacts buried")
      |> mes("around here inside town?")
      |> next()
      |> mes("[Alex]")
      |> mes("Besides, what makes you")
      |> mes("think that my brother would")
      |> mes("waste so much time doing")
      |> mes("something so ridiculous?")
      |> next()
      |> cutin("hu_laura03.bmp", 2)
      |> mes("[Laura]")
      |> mes("Hahahaha! Yeah,")
      |> mes("defend your brother")
      |> mes("as much as you like,")
      |> mes("you hypocrite! What do")
      |> mes("you care about him, I know")
      |> mes("you two really hate each other!")
      |> next()
      |> cutin("hu_alex04.bmp", 0)
      |> mes("[Alex]")
      |> mes("What was that...?")
      |> mes("I dare you to say")
      |> mes("that again! I'll make")
      |> mes("sure that you regret it!")
      |> next()
      |> cutin("hu_laura01.bmp", 2)
      |> mes("[Laura]")
      |> mes("I know that you were helping")
      |> mes("him in his excavations. There's")
      |> mes("no way so much progress can be")
      |> mes("done by one man alone! In fact,")
      |> mes("I have evidence that proves it!")
      |> next()
      |> mes("^3355FFLaura violently")
      |> mes("waves a thick file")
      |> mes("clasped in her hands.^000000")
      |> next()

    ctx =
      ctx
      |> emotion(:huk, getnpcid(ctx, "Julian#2"))
      |> mes("[Julian]")
      |> mes("What...?")
      |> mes("Argh, that's--!")
      |> next()

    ctx =
      ctx
      |> emotion(:anger, getnpcid(ctx, "Laura#2"))
      |> mes("[Laura]")
      |> mes("That's right.")
      |> mes("Now tell me, what the")
      |> mes("hell is ''^FF0000Ymir's Heart?^000000''")
      |> next()
      |> cutin("hu_alex02.bmp", 0)
      |> mes("[Alex]")
      |> mes("......")
      |> mes("Julian!")
      |> next()

    ctx =
      ctx
      |> emotion(:profusely_sweat, getnpcid(ctx, "Julian#2"))
      |> mes("[Julian]")
      |> mes("Uh, this isn't my fault!")
      |> mes("Sh-she doesn't have any")
      |> mes("right to come into our office!")
      |> next()
      |> cutin("hu_laura02.bmp", 2)
      |> mes("[Laura]")
      |> mes("Hah! Aren't we supposed to")
      |> mes("be equal partners in the same")
      |> mes("expedition? That's what I heard")
      |> mes("at the beginning! But you guys")
      |> mes("have something different in mind!")
      |> next()
      |> cutin("hu_laura03.bmp", 2)
      |> mes("[Laura]")
      |> mes("It's awfully suspicious: you")
      |> mes("guys are only going out at")
      |> mes("night, and you're making so")
      |> mes("little progress with the Odin")
      |> mes("Shrine excavation. Tell me,")
      |> mes("what are your true goals?!")
      |> next()
      |> cutin("hu_alex03.bmp", 0)

    ctx =
      ctx
      |> emotion(:profusely_sweat, getnpcid(ctx, "Alex#2"))
      |> mes("[Alex]")
      |> mes("I-I don't know what you're")
      |> mes("talking about! J-Julian must")
      |> mes("have gotten some mission, and")
      |> mes("has been carrying it out without my consent! Don't go twisting")
      |> mes("the facts, you... you thief!")
      |> next()
      |> cutin("hu_laura03.bmp", 2)
      |> mes("[Laura]")
      |> mes("Thief...?!")
      |> mes("Look who's")
      |> mes("talking!")
      |> next()
      |> mes("^3355FFLaura tossed the file")
      |> mes("away, and threateningly")
      |> mes("rolled up her sleeves.^000000")
      |> next()

    ctx =
      ctx
      |> emotion(:cry, getnpcid(ctx, "Ashe#2"))
      |> mes("[Ashe]")
      |> mes("S-stop!")
      |> mes("Both of you!")
      |> next()

    ctx =
      ctx
      |> emotion(:profusely_sweat, getnpcid(ctx, "Laura#2"))
      |> mes("[Laura]")
      |> mes("Stay out of")
      |> mes("this, Ashe!")
      |> next()
      |> cutin("hu_alex04.bmp", 0)

    ctx
    |> emotion(:fret, getnpcid(ctx, "Alex#2"))
    |> mes("[Alex]")
    |> mes("Yeah, this is none")
    |> mes("of your business!")
    |> next()
    |> set_char_var(:hg_odin, 25)
    |> mes("[Ashe]")
    |> mes("Oh... Oh, dear!")
    |> close()
    |> cutin("hu_alex04.bmp", 255)
  end

  defp aftermath(ctx) do
    ctx = cutin(ctx, "hu_laura03.bmp", 2)

    ctx =
      ctx
      |> emotion(:fret, getnpcid(ctx, "Laura#2"))
      |> mes("[Laura]")
      |> mes("Hah...!")
      |> mes("Did you...")
      |> mes("Just hit me?")
      |> next()
      |> cutin("hu_alex04.bmp", 0)

    ctx
    |> emotion(:fret, getnpcid(ctx, "Alex#2"))
    |> mes("[Alex]")
    |> mes("You crazy...!")
    |> close()
    |> cutin("hu_alex04.bmp", 255)
  end
end
