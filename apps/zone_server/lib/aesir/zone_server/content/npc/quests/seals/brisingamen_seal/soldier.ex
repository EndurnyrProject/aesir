defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Soldier do
  @moduledoc """
  Guards the entrance to the monster subjugation mission.

  ## Behavior

  - Admits volunteers and activates the next soldier when they enter.
  - Warns and turns away anyone else.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
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
        map: "que_god02",
        x: 54,
        y: 64,
        dir: 4,
        sprite: 105,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#1_brising",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :god_brising, 0) == 31 do
      {ctx, choice} =
        ctx
        |> mes("[Soldier]")
        |> mes(
          "Have you volunteered for monster subjugation? Would you like to start the mission now?"
        )
        |> next()
        |> select(["Yes.", "I need more time."])

      case choice do
        1 ->
          ctx
          |> mes("[Soldier]")
          |> mes("We're you're ready,")
          |> mes("come and stand in")
          |> mes("front of me.")
          |> close()

        2 ->
          ctx
          |> mes("[Soldier]")
          |> mes("No problem, just come back when your preparations are completed.")
          |> close()

        _ ->
          ctx
      end
    else
      ctx |> warning() |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :god_brising, 0) == 31 do
      ctx
      |> warp("que_god02", 174, 49)
      |> donpcevent("#brisinsold::OnSold1Off")
      |> donpcevent("#brisinsold2::OnSold2On")
    else
      ctx
      |> warning()
      |> close2()
      |> warp("que_god02", 51, 59)
    end
  end

  defp warning(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("Please back away.")
    |> mes("You are not permitted")
    |> mes("to enter!")
  end
end
