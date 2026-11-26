defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.YoungDancer7656 do
  @moduledoc """
  A young dancer talks about her upcoming performance aboard the airship.

  ## Behavior

  - Her dialogue changes with the spy quest stage.

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
        map: "airplane",
        x: 76,
        y: 56,
        dir: 4,
        sprite: 724,
        name: "Young Dancer",
        scope: :shared,
        unique_name: "Young Dancer#sch2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :que_sch, 0)

    cond do
      stage < 13 ->
        ctx
        |> mes("[Dancer]")
        |> mes("Hi there~")
        |> mes("Are you enjoying")
        |> mes("yourself? I hope so!")
        |> close()

      stage == 13 ->
        ctx
        |> mes("[Dancer]")
        |> mes("This will be my")
        |> mes("first performance...")
        |> mes("I guess that's why")
        |> mes("I have butterflies")
        |> mes("in my stomach...")
        |> close()

      true ->
        ctx
        |> mes("[Dancer]")
        |> mes("I wonder which beautiful")
        |> mes("place we'll get to perform in")
        |> mes("next time! Ooh, I can't wait!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
