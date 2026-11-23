defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Mirror do
  @moduledoc """
  The mirror reveals a clue about Tarsha during the airship ticket quest.

  ## Behavior

  - Shows a random reflection before advancing the quest.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
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
        map: "ein_in01",
        x: 121,
        y: 99,
        dir: 3,
        sprite: 111,
        name: "Mirror",
        scope: :shared,
        unique_name: "Mirror#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :kain_ticket, 0) == 8 do
      ctx =
        ctx
        |> mes("^3355FFIt's a mirror.")
        |> mes("So, of course the")
        |> mes("first thing you'll")
        |> mes("see is yourself.")
        |> next()
        |> set_local(:r, Enum.random(1..5))

      roll = get_local(ctx, :r, 0)
      ctx = if roll == 5, do: reflection(ctx, :any, roll), else: reflection(ctx, sex(ctx), roll)

      ctx
      |> next()
      |> mes("^3355FFAfter enjoying that")
      |> mes("little epiphany, you")
      |> mes("see a reflection of")
      |> mes("Tarsha's neck as you")
      |> mes("set the mirror back down.^000000")
      |> next()
      |> mes("^3355FFAs you take a closer")
      |> mes("look, you find that there's")
      |> mes("a strange mark around her")
      |> mes("neck. What ever could it mean?^000000")
      |> set_char_var(:kain_ticket, 9)
      |> close()
    else
      ctx
    end
  end

  defp reflection(ctx, :any, 5) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh wow...")
    |> mes("I look pretty good.")
    |> mes("No wait. Really, really")
    |> mes("good. So this must be")
    |> mes("why I get such great")
    |> mes("service at restaurants...")
  end

  defp reflection(ctx, 1, 1) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Man...")
    |> mes("I didn't know")
    |> mes("I was so good")
    |> mes("looking! Ooh yah~")
  end

  defp reflection(ctx, 1, 2) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Whoa...")
    |> mes("So that's why the")
    |> mes("ladies keep looking")
    |> mes("at me. I'm a walking")
    |> mes("free gun show!")
  end

  defp reflection(ctx, 1, 3) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("It's a shame I can't job")
    |> mes("change to Male Model.")
    |> mes("Clearly, I'd be like, Job")
    |> mes("Level 87 or something.")
    |> mes("Man, I'm beautiful...")
  end

  defp reflection(ctx, 1, 4) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("This is my reflection?!")
    |> mes("No one can be this good")
    |> mes("looking, not without special")
    |> mes("effects! I mean, it's not")
    |> mes("fair to everyone else...")
  end

  defp reflection(ctx, _sex, 1) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh. Wow.")
    |> mes("I never realized...")
    |> mes("Everything is in")
    |> mes("perfect proportion!")
    |> mes("No wonder people")
    |> mes("want to party with me~")
  end

  defp reflection(ctx, _sex, 2) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh my gosh~")
    |> mes("How can I look this")
    |> mes("good without any makeup?")
    |> mes("I-It isn't fair to all the other")
    |> mes("girls... Wow, is this really me?")
  end

  defp reflection(ctx, _sex, 3) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Am I going crazy?")
    |> mes("Is that girl in the")
    |> mes("mirror really me...?")
    |> mes("How did I not realize")
    |> mes("how gorgeous I look?")
  end

  defp reflection(ctx, _sex, 4) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("So...")
      |> mes("What did you do with")
      |> mes("this mirror? Because I'm")
      |> mes("looking at my reflection")
      |> mes("and I can't seem to find")
      |> mes("any flaws with my figure...")
      |> next()

    ctx =
      ctx
      |> emotion(:profusely_sweat, getnpcid(ctx, "Tarsha Cherno"))
      |> mes("[Tarsha Cherno]")
      |> mes("Actually...")
      |> mes("That's not one")
      |> mes("of our inventions.")
      |> mes("It's just a normal mirror...")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Well now...!")
    |> mes("Are you sure?")
    |> mes("Because my face looks")
    |> mes("freakin' immaculate! And")
    |> mes("it's like, I'm almost too sexy!")
  end

  defp reflection(ctx, _sex, _roll), do: ctx
end
