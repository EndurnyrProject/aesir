defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.Bpast11 do
  @moduledoc """
  A scream awakens the player in the laboratory vision.

  ## Behavior

  - Players before stage 4 are warped away; others recover and see the burning building.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "que_ba",
        x: 247,
        y: 33,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#bpast_1_1",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    enter_vision(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    enter_vision(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp enter_vision(ctx) do
    if get_char_var(ctx, :barmunt_crow, 0) < 4 do
      warp(ctx, "ama_dun03", 119, 110)
    else
      ctx
      |> sc_end(:sc_blind)
      |> mes("[???]")
      |> mes("Waaaaah!")
      |> next()
      |> mes(
        "^660000Startled by a terrifying scream, you regained consciousness. It seems that you were lost in time for quite a while.^000000"
      )
      |> next()
      |> mes(
        "^660000You scrambled to stand on you feet, and then followed the sound of the scream to an old and abandoned building.^000000"
      )
      |> next()
      |> mes(
        "^660000The old, huge and somehow intimidating building was expelling dark red smoke out of broken and open windows.^000000"
      )
      |> close()
    end
  end
end
