defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.YoungDancer do
  @moduledoc """
  A young dancer prepares to depart for a performance.

  ## Behavior

  - At the appropriate quest stage, offers to take the player aboard the airship.

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
        x: 85,
        y: 49,
        dir: 0,
        sprite: 724,
        name: "Young Dancer",
        scope: :shared,
        unique_name: "Young Dancer#sch1"
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
        depart(ctx)

      true ->
        ctx
        |> mes("[Dancer]")
        |> mes("Oh, that was such a fun")
        |> mes("performance. I can still")
        |> mes("see the dazzling decorations")
        |> mes("in the ballroom where we got")
        |> mes("to dance. It was so wonderful!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp depart(ctx) do
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
  end
end
