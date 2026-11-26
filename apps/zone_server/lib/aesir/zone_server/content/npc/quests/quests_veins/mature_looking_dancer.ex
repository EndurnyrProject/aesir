defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.MatureLookingDancer do
  @moduledoc """
  A dancer accompanies the bodyguard on a trip.

  ## Behavior

  - Offers passage to the airship when the bodyguard is ready.

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
        x: 87,
        y: 50,
        dir: 2,
        sprite: 724,
        name: "Mature Looking Dancer",
        scope: :shared,
        unique_name: "Mature Looking Dancer#s1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :que_sch, 0) do
      stage when stage < 12 ->
        ctx
        |> mes("[Dancer]")
        |> mes("Hi there~")
        |> mes("Are you enjoying")
        |> mes("yourself? I hope so!")
        |> close()

      12 ->
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

      _ ->
        ctx
        |> mes("[Dancer]")
        |> mes("I sure learned a lot from")
        |> mes("that trip. I hope that the new")
        |> mes("girls also gained something")
        |> mes("from their experiences.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
