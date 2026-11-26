defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.CheerfulDancer172266 do
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
        map: "ein_in01",
        x: 172,
        y: 266,
        dir: 0,
        sprite: 724,
        name: "Cheerful Dancer",
        scope: :shared,
        unique_name: "Cheerful Dancer#sch3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :que_sch, 0)

    cond do
      stage < 17 ->
        ctx
        |> mes("[Dancer]")
        |> mes("The dinner party isn't")
        |> mes("even finished yet, but")
        |> mes("I'm already exhausted~")
        |> close()

      stage == 17 ->
        ctx
        |> mes("[Dancer]")
        |> mes("^333333*Whew*^000000 We gave a good")
        |> mes("performance this time.")
        |> mes("I was worried since that")
        |> mes("airship trip really drained me.")
        |> close()

      true ->
        ctx
        |> mes("[Dancer]")
        |> mes("Dancing is really")
        |> mes("hard work, and all that")
        |> mes("practicing wears you out,")
        |> mes("but it's worth it once you")
        |> mes("get up on that stage.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
