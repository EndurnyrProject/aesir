defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.YoungDancer174266 do
  @moduledoc """
  A young dancer discusses her performance at the dinner party.

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
        map: "ein_in01",
        x: 174,
        y: 266,
        dir: 0,
        sprite: 724,
        name: "Young Dancer",
        scope: :shared,
        unique_name: "Young Dancer#sch3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :que_sch, 0)

    cond do
      stage < 17 ->
        ctx
        |> mes("[Dancer]")
        |> mes("Oh, the dinner")
        |> mes("party isn't finished yet.")
        |> mes("It'll be over before")
        |> mes("you even know it~")
        |> close()

      stage == 17 ->
        ctx
        |> mes("[Dancer]")
        |> mes("Hooray! My first")
        |> mes("onstage performance")
        |> mes("was a success! Oh")
        |> mes("I was so nervous...")
        |> mes("But I'm so proud")
        |> mes("of myself now!")
        |> close()

      true ->
        ctx
        |> mes("[Dancer]")
        |> mes("Without dance,")
        |> mes("my life has no")
        |> mes("meaning at all.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
