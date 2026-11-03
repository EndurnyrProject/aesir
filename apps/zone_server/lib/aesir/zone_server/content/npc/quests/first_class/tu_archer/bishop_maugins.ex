defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.BishopMaugins do
  @moduledoc """
  Bishop Maugins of the St. Capitolina Abbey, the last stop of the Archer palace errand.

  ## Behavior

  - At Archer errand step 7, asking whether something happened to the Kingdom advances
    the errand step to 8; either answer ends with Increase Agility and Blessing.
  - Otherwise he asks the player to come back later.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "monk_in", x: 19, y: 43, dir: 1, sprite: 60, name: "Bishop Maugins", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Bishop Maugins]")

    if get_char_var(ctx, :tu_archer02, 0) == 7 do
      palace_inquiry(ctx)
    else
      ctx
      |> mes("I'm sorry, but I have")
      |> mes("some pressing matter")
      |> mes("to think about right now.")
      |> mes("Would you come back later?")
      |> close()
    end
  end

  defp palace_inquiry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Greetings.")
      |> mes(
        "I doubt that you're here to change to the Monk job, but may I help you with something? Perhaps you're"
      )
      |> mes("here for a confession?")
      |> next()
      |> mes("[Bishop Maugins]")
      |> mes("Hm? Work related to")
      |> mes("the Palace? Yes, I'm in")
      |> mes("charge of that area. So")
      |> mes("how may I help you?")
      |> next()
      |> select(["Has something happened to the Kingdom?", "Nothing."])

    ctx =
      if choice == 1 do
        ctx
        |> mes("[Bishop Maugins]")
        |> mes("...!!")
        |> next()
        |> mes("[Bishop Maugins]")
        |> mes("...")
        |> mes("......")
        |> next()
        |> mes("[Bishop Maugins]")
        |> mes("Ho ho~")
        |> mes("Of course not!")
        |> mes(
          "The king and I regularly write to each other, but I haven't heard of anything in particular. Please don't worry yourself."
        )
        |> next()
        |> set_char_var(:tu_archer02, 8)
      else
        ctx
      end

    ctx
    |> mes("[Bishop Maugins]")
    |> mes("Good luck on")
    |> mes("your journeys,")
    |> mes("brave adventurer.")
    |> npcskill(29, 10, 0, 0)
    |> npcskill(34, 10, 0, 0)
    |> close()
  end
end
