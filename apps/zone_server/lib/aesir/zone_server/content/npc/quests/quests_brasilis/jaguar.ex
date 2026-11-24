defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Jaguar do
  @moduledoc """
  Jaguar advances the Guarana Candy quest and blesses the adventurer.

  ## Behavior

  - Gives quest participants meat and a speed blessing after advancing the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_fild01",
        x: 34,
        y: 184,
        dir: 5,
        sprite: 2072,
        name: "Jaguar",
        scope: :shared,
        unique_name: "Jaguar#bra",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    talk_to_animal(ctx)
  end

  @impl true
  def on_talk(ctx) do
    talk_to_animal(ctx)
  end

  defp talk_to_animal(ctx) do
    if get_char_var(ctx, :brazil_gua, 0) == 7 do
      ctx =
        ctx
        |> mes("[Jaguar]")
        |> mes("Hhooww..hhooww.....")
        |> next()
        |> mes("[Jaguar]")
        |> mes("Smelling! This smell is from a human!")
        |> mes("Somewhere, a human!")
        |> mes("I got it. You are!!!")
        |> specialeffect(:hit1, :area, "Jaguar#bra")

      {ctx, _} =
        ctx
        |> emotion(:huk, playerattached(ctx))
        |> next()
        |> mes("[Jaguar]")
        |> mes("Don't be afraid human.")
        |> mes(
          "I don't have enough power to hunt humans, just waiting time to end my lifetime in this jungle."
        )
        |> next()
        |> mes("[Jaguar]")
        |> mes("Anyway you can talk with me, are you a guarana kid?")
        |> next()
        |> select(["Yes? N...o......actually...."])

      ctx
      |> mes("[Jaguar]")
      |> mes("The son of guarana woman became our friend also.")
      |> mes("They treated all life preciously.")
      |> mes("I hope you are same the as her.")
      |> next()
      |> mes("[Jaguar]")
      |> mes("Bird's chirpings informed me.")
      |> mes("The son of guarana woman has a diseased heart.")
      |> mes("Her brothers made him lonely, don't you think?")
      |> next()
      |> mes("[Jaguar]")
      |> mes("Here is fresh meat that I hunted just a few days ago.")
      |> mes("Take it and give it to the poor kid.")
      |> next()
      |> mes("[Jaguar]")
      |> mes("I can give this tiny thing to you so, don't forget it.")
      |> mes("The jungle will welcome you whenever!")
      |> next()
      |> mes("- You get fresh meat from Jaguar. -")
      |> next()
      |> mes("[Jaguar]")
      |> mes("Monkey, who's always meddling with others, wants to meet you.")
      |> next()
      |> mes("[Jaguar]")
      |> mes("I will give you a Jaguar's high blessing.")
      |> mes("Go to monkey by flowing through the wind like a bee.")
      |> mes("Let's meet again my friend!")
      |> set_char_var(:brazil_gua, 8)
      |> changequest(2197, 2198)
      |> close()
      |> consumeitem(12016)
    else
      ctx |> mes("[Jaguar]") |> mes("krrrrrr....") |> close()
    end
  end
end
