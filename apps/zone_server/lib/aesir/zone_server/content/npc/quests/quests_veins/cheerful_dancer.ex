defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.CheerfulDancer do
  @moduledoc """
  A cheerful dancer escorts the hired bodyguard to the airship.

  ## Behavior

  - She offers departure when the player is ready and comments on her performance afterward.

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
        map: "job_duncer",
        x: 83,
        y: 52,
        dir: 6,
        sprite: 724,
        name: "Cheerful Dancer",
        scope: :shared,
        unique_name: "Cheerful Dancer#sch1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :que_sch, 0)

    cond do
      stage < 12 ->
        ctx
        |> mes("[Dancer]")
        |> mes("Hi there~")
        |> mes("Are you enjoying")
        |> mes("yourself? I hope so!")
        |> close()

      stage == 12 ->
        {ctx, choice} =
          ctx
          |> mes("[Dancer]")
          |> mes("Ah, you must be the")
          |> mes("bodyguard. So are you")
          |> mes("ready to go now?")
          |> next()
          |> select(["Yes", "No"])

        if choice == 1 do
          ctx
          |> mes("[Dancer]")
          |> mes("Alright, then.")
          |> mes("Here we go~")
          |> set_char_var(:que_sch, 13)
          |> close2()
          |> warp("airplane", 75, 55)
        else
          ctx
          |> mes("[Dancer]")
          |> mes("We need to depart soon,")
          |> mes("so please hurry. I'll be")
          |> mes("waiting for you here~")
          |> close()
        end

      true ->
        ctx
        |> mes("[Dancer]")
        |> mes("I guess it's pretty")
        |> mes("fun to perform on stage~")
        |> mes("But I still need to practice")
        |> mes("more for the next performance.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
