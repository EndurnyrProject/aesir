defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.PostellSchuwell34123 do
  @moduledoc """
  Postell discusses his father's medicine and asks the player to check on him.

  ## Behavior

  - Advances Allen's medicine quest when the player persuades Postell to help.
  - Describes Postell's concern about his father's medicine at other stages.

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
        map: "hu_fild06",
        x: 34,
        y: 123,
        dir: 3,
        sprite: 97,
        name: "Postell Schuwell",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :hg_herb, 0)

    cond do
      stage == 1 ->
        {ctx, choice} =
          ctx
          |> mes("[Postell]")
          |> mes("I really like living")
          |> mes("in Hugel. Fresh air,")
          |> mes("clean water, everyone's")
          |> mes("friendly and nice. What")
          |> mes("more could I want?")
          |> next()
          |> mes("[Postell]")
          |> mes("Oh, what's that?")
          |> mes("My dad wants me to")
          |> mes("bring him some medicine?")
          |> mes("Again? Well, he was really")
          |> mes("sick a long time ago, but")
          |> mes("nowadays, I'm not so sure.")
          |> next()
          |> mes("[Postell]")
          |> mes("I mean, I'm pretty sure")
          |> mes("his illnesses are all, you")
          |> mes("know, psychosomatic.")
          |> mes("Besides, I'm worried that")
          |> mes("all the medicines he's taking")
          |> mes("are habit forming, you know?")
          |> next()
          |> select(["But your father needs you!", "Habit forming?"])

        case choice do
          1 ->
            ctx
            |> mes("[Allen's Voice]")
            |> mes("Yeah, I guess you're right.")
            |> mes("Even if I think he's nuts,")
            |> mes("and I don't agree with him,")
            |> mes("I should at least show that")
            |> mes("I care about my dad. What")
            |> mes("medicine did he say he needed?")
            |> next()
            |> mes("[Postell]")
            |> mes("''Kolbun A?'' Alright,")
            |> mes("I better make sure that")
            |> mes("it's safe for him to take.")
            |> mes("Who knows, that stuff might")
            |> mes("make him worse. Anyway,")
            |> mes("I'll try to get it to him soon.")
            |> next()
            |> mes("[Postell]")
            |> mes("Hey, would you do")
            |> mes("me a favor and make")
            |> mes("sure that my dad doesn't")
            |> mes("get himself into any")
            |> mes("more trouble? I'd really")
            |> mes("appreciate it if you do.")
            |> set_char_var(:hg_herb, 2)
            |> changequest(8053, 8054)
            |> close()

          2 ->
            ctx
            |> mes("[Postell]")
            |> mes("Yeah, like he's addicted")
            |> mes("to the medicine. That's why")
            |> mes("I'm trying to make sure he")
            |> mes("gets as little of it as possible! Honestly, I think he drinks")
            |> mes("too much medicine already...")
            |> close()

          _ ->
            ctx
        end

      stage > 1 ->
        ctx
        |> mes("[Postell]")
        |> mes("Kolbun A, Kolbun A...")
        |> mes("Let's see, is it really")
        |> mes("safe for my dad to take?")
        |> mes("If it isn't, I better come up")
        |> mes("with some replacement...")
        |> close()

      true ->
        ctx
        |> mes("[Postell]")
        |> mes("I really like living")
        |> mes("in Hugel. Fresh air,")
        |> mes("clean water, everyone's")
        |> mes("friendly and nice. What")
        |> mes("more could I want?")
        |> close()
    end
  end
end
