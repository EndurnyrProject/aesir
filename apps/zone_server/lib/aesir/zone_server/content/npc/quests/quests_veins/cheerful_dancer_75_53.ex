defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.CheerfulDancer7553 do
  @moduledoc """
  A cheerful dancer shares her thoughts about performing.

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
        x: 75,
        y: 53,
        dir: 0,
        sprite: 724,
        name: "Cheerful Dancer",
        scope: :shared,
        unique_name: "Cheerful Dancer#sch2"
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
        |> mes("I've performed at many")
        |> mes("venues, but this is the")
        |> mes("frist time I'll be dancing")
        |> mes("in the Schwarzwald Republic.")
        |> mes("This is also my first time on")
        |> mes("an airship. How exciting!")
        |> close()

      true ->
        ctx
        |> mes("[Dancer]")
        |> mes("Traveling is really")
        |> mes("thrilling... It's almost as")
        |> mes("fun as dancing on stage~")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
