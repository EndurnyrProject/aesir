defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.StrangeOldMan do
  @moduledoc """
  Absar builds an invention for Zabaroo.

  ## Behavior

  - He requests materials and constructs a tool for the stone quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 169,
        y: 310,
        dir: 6,
        sprite: 121,
        name: "Strange Old Man",
        scope: :shared,
        unique_name: "Strange Old Man#ve"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :veins_stone, 0) do
      0 ->
        ctx
        |> mes("[Absar]")
        |> mes("Bwahahaha!")
        |> mes("Once... Once this is completed, I'll...")
        |> mes("Mwahahahahahahahah!")
        |> close()

      1 ->
        start_invention(ctx)

      2 ->
        bring_materials(ctx)

      3 ->
        collect_invention(ctx)

      _ ->
        ctx
        |> mes("[Absar]")
        |> mes("It's a ''Tactile Extendable")
        |> mes("Clamp-Release Mechanism.''")
        |> mes("What's so hard to understand")
        |> mes("about that? Hmpf! I know!")
        |> mes("It must be the educational")
        |> mes("system! They're to blame!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp start_invention(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Absar]")
      |> mes("I'm so close to")
      |> mes("completion. Now, if")
      |> mes("I just turn this here...")
      |> next()
      |> select(["Excuse me...", "........"])

    if choice == 1 do
      ctx
      |> mes("[Absar]")
      |> mes("What?! Who dares")
      |> mes("disturb me?! N-no!")
      |> mes("Look! Look what you did!")
      |> mes("You made me screw up!")
      |> next()
      |> specialeffect(:lord)
      |> percent_heal(hp: -30, sp: 0)
      |> next()
      |> mes("[Absar]")
      |> mes("!@#$%#@#$!*~")
      |> mes("F$#@#%^^^&&!")
      |> close2()
      |> warp("ve_in", 262, 309)
    else
      discuss_invention(ctx)
    end
  end

  defp discuss_invention(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Absar]")
      |> mes("Oh, no...")
      |> next()
      |> specialeffect(:aspersio)
      |> next()
      |> mes("[Absar]")
      |> mes("How...?!")
      |> mes("No! I failed again!")
      |> mes("D-DAAAAAAAAAAAMN IIIII--")
      |> next()
      |> mes("[Absar]")
      |> mes("Huh? What are you...")
      |> mes("What do you want?")
      |> next()
      |> select(["Oh, I-I'm..."])

    {ctx, choice} =
      ctx
      |> mes("[Absar]")
      |> mes("Spit it out. Tell me")
      |> mes("what you want, not your")
      |> mes("name. Hurry, can't you")
      |> mes("see that I'm busy?")
      |> next()
      |> select(["I... I'm sorry.", "I'm here for Mr. Zabaroo..."])

    if choice == 1 do
      ctx
      |> mes("[Absar]")
      |> mes("If only you didn't")
      |> mes("interrupt me! Then")
      |> mes("I'd already have...")
      |> mes("Ugh! Back to work!")
      |> close()
    else
      request_materials(ctx)
    end
  end

  defp request_materials(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Absar]")
      |> mes("Zabaroo? What does...")
      |> mes("Oh. Never mind. I think")
      |> mes("I remember what he asked")
      |> mes("me to make him. So did")
      |> mes("you bring all the materials?")
      |> next()
      |> select(["Yes", "What materials...?"])

    if choice == 1 do
      ctx
      |> mes("[Absar]")
      |> mes("Great, we can get")
      |> mes("started and m--")
      |> mes("Liar. You don't even know")
      |> mes("what you're supposed to")
      |> mes("bring me, do you?!")
      |> mes("Get out of here!")
      |> close2()
      |> warp("ve_in", 262, 309)
    else
      ctx
      |> mes("[Absar]")
      |> mes("Of course. I didn't tell him")
      |> mes("what materials I needed")
      |> mes("anyway. Heh heh! Now, this")
      |> mes("is what I need you to bring.")
      |> mes("Listen up, okay? And hurry.")
      |> next()
      |> mes("[Absar]")
      |> mes("^4D4DFF5 Maneater Roots^000000,")
      |> mes("^4D4DFF2 Glacial Hearts^000000, and")
      |> mes("^4D4DFF5 Steel^000000. If you don't")
      |> mes("come back soon, then")
      |> mes("I won't help you. I've got")
      |> mes("projects I'm working on!")
      |> set_char_var(:veins_stone, 2)
      |> close()
    end
  end

  defp bring_materials(ctx) do
    if count_item(ctx, 999) > 4 and count_item(ctx, 1033) > 4 and
         count_item(ctx, 7561) > 1 do
      ctx
      |> mes("[Absar]")
      |> mes("Good, you finally")
      |> mes("brought everthing.")
      |> mes("I was just about to")
      |> mes("give up on you, so")
      |> mes("consider yourself lucky!")
      |> next()
      |> mes("[Absar]")
      |> mes("Give me a second.")
      |> mes("You won't have to")
      |> mes("wait long to see")
      |> mes("my great invention!")
      |> delitem(999, 5)
      |> delitem(1033, 5)
      |> delitem(7561, 2)
      |> set_char_var(:veins_stone, 3)
      |> close2()
      |> specialeffect(:firesplashhit)
    else
      ctx
      |> mes("[Absar]")
      |> mes("What the hell?")
      |> mes("Hurry and bring")
      |> mes("^4D4DFF5 Maneater Roots^000000,")
      |> mes("^4D4DFF2 Glacial Hearts^000000, and")
      |> mes("^4D4DFF5 Steel^000000! Do you think")
      |> mes("I'm doing this for fun?!")
      |> close()
    end
  end

  defp collect_invention(ctx) do
    ctx =
      ctx
      |> mes("[Absar]")
      |> mes("Here you are...")
      |> mes("Well, I don't know")
      |> mes("if you appreciate")
      |> mes("inventions, but this")
      |> mes("is a Tactile Extendable")
      |> mes("Clamp-Release Mechanism!")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Tack... What...?")
    |> next()
    |> mes("[Absar]")
    |> mes("...............................")
    |> mes("You can use this to pick")
    |> mes("things up. From a distance.")
    |> next()
    |> mes("[Absar]")
    |> mes("Anyway, when you get back")
    |> mes("to Zabaroo, let me him know")
    |> mes("that he doesn't owe me")
    |> mes("anything anymore. He'll...")
    |> mes("He'll know what I mean...")
    |> set_char_var(:veins_stone, 4)
    |> close()
  end
end
