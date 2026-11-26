defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.FactoryWorker do
  @moduledoc """
  Bahed processes stones brought to the factory.

  ## Behavior

  - He accepts Zabaroo’s stones and explains what he knows about Hetarium.

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
        map: "ve_in02",
        x: 54,
        y: 49,
        dir: 2,
        sprite: 943,
        name: "Factory Worker",
        scope: :shared,
        unique_name: "Factory Worker#ve1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :veins_stone, 0) do
      stage when stage < 6 ->
        ctx
        |> mes("[Bahed]")
        |> mes("lately, I've been feeling so weak...")
        |> mes("I heard the guy before me had to quit because he also started feeling weak.")
        |> next()
        |> mes("[Bahed]")
        |> mes("It couldn't be...")
        |> mes("It couldn't be because of this 'Hetarium'...")
        |> mes("That's just plain crazy...")
        |> close()

      6 ->
        {ctx, _} =
          ctx
          |> mes("[Bahed]")
          |> mes("Oh, you got the rocks?")
          |> mes("You brought them for Zabaroo?")
          |> mes("Oh, how is he doing? I hear")
          |> mes("he threw out his back.")
          |> next()
          |> select(["He still hurts."])

        {ctx, _} =
          ctx
          |> mes("[Bahed]")
          |> mes("Oh no... I'm so sorry")
          |> mes("to hear that. I hope he")
          |> mes("feels better soon. Anyway,")
          |> mes("why don't you bring the")
          |> mes("rocks over here?")
          |> next()
          |> mes("[Bahed]")
          |> mes("Let me confirm Zabaroo's")
          |> mes("quota for today. Ah, and")
          |> mes("don't worry, we pay him")
          |> mes("for his quotas regularly.")
          |> next()
          |> select(["I have a question..."])

        {ctx, _} =
          ctx
          |> mes("[Bahed]")
          |> mes("Hm? What'd you want")
          |> mes("to know? I can't say that")
          |> mes("I know everything, but")
          |> mes("I'll try my best to tell you")
          |> mes("what I know. I mean,")
          |> mes("you helped Zabaroo, so...")
          |> next()
          |> select(["What's this Hetarium??"])

        {ctx, _} =
          ctx
          |> mes("[Bahed]")
          |> mes("Well, it hasn't been that")
          |> mes("long since these rocks")
          |> mes("attracted attention outside")
          |> mes("of town. Before all this,")
          |> mes("the townspeople just")
          |> mes("made carvings out of them.")
          |> next()
          |> mes("[Bahed]")
          |> mes("Then, all of a sudden,")
          |> mes("these people from--I guess")
          |> mes("it was Schwarzwald--came")
          |> mes("and bought a lot of these")
          |> mes("stones. Later, they even built")
          |> mes("this factory to process them!")
          |> next()
          |> mes("[Bahed]")
          |> mes("Oh, they tried using machines")
          |> mes("to harvest these stones, but")
          |> mes("they all broke down too soon.")
          |> mes("That's why they hired people")
          |> mes("in Veins to collect them.")
          |> next()
          |> mes("[Bahed]")
          |> mes("I'm not sure many people")
          |> mes("know who owns this factory.")
          |> mes("Maybe it's Rekenber? Yes,")
          |> mes("I saw one of their corporate")
          |> mes("airships come to town, so")
          |> mes("I think it might be them.")
          |> next()
          |> select(["How do they use Hetarium??"])

        ctx
        |> mes("[Bahed]")
        |> mes("I'm not really sure. I just")
        |> mes("happened to overhear some")
        |> mes("of the higher ups mention")
        |> mes("something about hearts?")
        |> mes("Pieces of hearts? Doesn't")
        |> mes("make any sense to me.")
        |> next()
        |> mes("[Bahed]")
        |> mes("All I gathered was that")
        |> mes("they were using the stones")
        |> mes("to build a machine related")
        |> mes("to those hearts. That's")
        |> mes("all I know. Anyway, please")
        |> mes("leave the stones over there~")
        |> set_char_var(:veins_stone, 7)
        |> close()

      _ ->
        ctx
        |> mes("[Bahed]")
        |> mes("Everyday I feel")
        |> mes("weaker and weaker...")
        |> mes("Could this be chronic")
        |> mes("fatigue syndrome? Ugh...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
