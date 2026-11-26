defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Brisindwarf3 do
  @moduledoc """
  Guards Berling's summoning barrier in a bubbling stream.

  ## Behavior

  - Challenges eligible players with a question and summons Berling for the correct answer.
  - Surprises players who have progressed far enough when they approach.

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
        map: "mjolnir_09",
        x: 85,
        y: 129,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#brisindwarf3",
        trigger: {3, 3}
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
    cond do
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        describe_stream(ctx)

      get_server_var(ctx, "God3", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        describe_stream(ctx)

      get_char_var(ctx, :god_brising, 0) > 42 and get_char_var(ctx, :god_brising, 0) < 50 ->
        challenge(ctx)

      true ->
        describe_stream(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :god_brising, 0) > 42 do
      emotion(ctx, :surprise, playerattached(ctx))
    else
      ctx
    end
  end

  defp describe_stream(ctx) do
    ctx
    |> mes("^3355FFThe sight of this bubbling stream refreshes you just by looking at it.^000000")
    |> close()
  end

  defp challenge(ctx) do
    {ctx, answer} =
      ctx
      |> specialeffect(:bubble)
      |> mes("[Echoing Voice]")
      |> mes("Alfrik: confirmed.")
      |> mes("Dvalin: confirmed.")
      |> next()
      |> mes("[Echoing Voice]")
      |> mes("Please answer me.")
      |> mes("Odin punished beautiful")
      |> mes("Freya, and made her curse")
      |> mes("some humans with her power.")
      |> next()
      |> mes("[Echoing Voice]")
      |> mes(
        "Freya caused an eternal battle, where the combatants were all killed and brought back to life everyday. How many humans were cursed to participate?"
      )
      |> next()
      |> select(["20!", "How should I know?!", "40!", "42!"])

    case answer do
      answer when answer in 1..3 ->
        ctx
        |> specialeffect(:bubble)
        |> mes("[Echoing Voice]")
        |> mes("Failed.")
        |> mes("Failed...")
        |> close()

      4 ->
        ctx
        |> specialeffect(:bubble)
        |> mes("[Echoing Voice]")
        |> mes("...Confirmed.")
        |> mes("Shutting down barrier.")
        |> mes("Initiating summoning.")
        |> next()
        |> hideoffnpc("Berling#1")
        |> mes("[Berling]")
        |> mes("^333333*Gasp--!*^000000")
        |> mes("Thought I was")
        |> mes("gonna drown to death!")
        |> mes("Who woke me up?")
        |> close()

      _ ->
        ctx
    end
  end
end
