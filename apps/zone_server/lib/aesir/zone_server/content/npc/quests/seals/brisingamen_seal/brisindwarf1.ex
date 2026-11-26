defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Brisindwarf1 do
  @moduledoc """
  Hides Alfrik beneath a snow mound and challenges visitors with a lyric puzzle.

  ## Behavior

  - Eligible visitors can uncover the puzzle and awaken Alfrik by choosing the correct lyrics.
  - Touching the mound surprises players who have progressed in the quest.

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
        map: "xmas",
        x: 38,
        y: 105,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#brisindwarf1",
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
    if get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check1", 0) or
         get_server_var(ctx, "God3", 0) >= get_server_temp_var(ctx, "god_check2", 0) or
         get_char_var(ctx, :god_brising, 0) <= 39 or
         get_char_var(ctx, :god_brising, 0) >= 50 do
      ctx |> snow() |> close()
    else
      {ctx, choice} =
        ctx
        |> snow()
        |> next()
        |> mes(
          "^3355FFHowever, this particular mound strikes you as curious for some reason.^000000"
        )
        |> next()
        |> select([
          "Sweep the snow away with your hand.",
          "Poke the snow with your finger.",
          "Cancel."
        ])

      case choice do
        1 ->
          uncover_puzzle(ctx)

        2 ->
          ctx
          |> player_name()
          |> mes("This...")
          |> mes("This better not")
          |> mes("be just some regular")
          |> mes("puzzle cube that someone")
          |> mes("just dropped in the snow!")
          |> close()

        3 ->
          ctx
          |> mes(
            "^3355FFYou use your finger to poke the pile of snow. However, you hurt your finger a little bit after hitting something really solid.^000000"
          )
          |> emotion(:anger, playerattached(ctx))
          |> percent_heal(hp: -20, sp: 0)
          |> close()

        4 ->
          close(ctx)

        _ ->
          ctx
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :god_brising, 0) > 39 do
      emotion(ctx, :surprise, playerattached(ctx))
    else
      ctx
    end
  end

  defp snow(ctx) do
    ctx
    |> mes("^3355FFA lot of snow")
    |> mes("is heavily piled")
    |> mes("here on the ground.^000000")
  end

  defp player_name(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")

  defp uncover_puzzle(ctx) do
    {ctx, choice} =
      ctx
      |> mes(
        "^3355FFAs you sweep the snow with the palm of your hand, some of the snow melts, revealing a strange puzzle cube. It's multi-faceted, but you can read that each facet is inscribed with a lyric."
      )
      |> next()
      |> select(["Adjust the puzzle.", "Quit."])

    case choice do
      1 ->
        ctx
        |> player_name()
        |> mes("Okay, um...")
        |> mes("I guess I should")
        |> mes("choose a lyric...")
        |> next()
        |> choose_lyric(1)

      2 ->
        ctx
        |> player_name()
        |> mes("Huh...?")
        |> mes("Nothing happened.")
        |> mes("Did I do something wrong, or is this just a completely ordinary puzzle cube?")
        |> close()

      _ ->
        ctx
    end
  end

  defp choose_lyric(ctx, 6) do
    ctx = next(ctx)

    if get_local(ctx, :point, 0) > 40 do
      ctx
      |> hideoffnpc("Alfrik#1")
      |> mes("[Old dwarf]")
      |> mes("Who are you?!")
      |> mes("And why the hell")
      |> mes("did you wake me up?")
      |> close()
    else
      close(ctx)
    end
  end

  defp choose_lyric(ctx, step) do
    {options, responses, correct} = lyric_options(step)
    {ctx, choice} = select(ctx, options)

    if choice in 1..5 do
      ctx = if step == 1, do: player_name(ctx), else: ctx
      ctx = mes(ctx, Enum.at(responses, choice - 1))

      ctx =
        if choice == correct,
          do: set_local(ctx, :point, get_local(ctx, :point, 0) + 10),
          else: ctx

      choose_lyric(ctx, step + 1)
    else
      ctx
    end
  end

  defp lyric_options(1) do
    {[
       "Wanes in comparison",
       "To that beautiful hair",
       "All of our hearts",
       "The beauty of the stars",
       "To those dazzling eyes"
     ],
     [
       "we gave...",
       "To that beautiful hair",
       "All of our hearts in",
       "The beauty of the stars",
       "To those dazzling eyes"
     ], 4}
  end

  defp lyric_options(2) do
    {[
       "We gave",
       "Wanes in comparison.",
       "All of our hearts in",
       "To the steps in",
       "To those dazzling eyes"
     ],
     [
       "we gave..",
       "Wanes in comparison.",
       "All of our hearts in",
       "To the steps in",
       "To those dazzling eyes"
     ], 2}
  end

  defp lyric_options(3) do
    {[
       "We gave",
       "To that beautiful hair",
       "All of our hearts in",
       "To the steps in",
       "We lost our hearts"
     ],
     [
       "We gave",
       "To that beautiful hair",
       "All of our hearts in",
       "To the steps in",
       "We lost our hearts"
     ], 5}
  end

  defp lyric_options(4) do
    {[
       "To that golden hair",
       "To that beautiful hair",
       "All of our hearts in",
       "To the steps in",
       "To those dazzling eyes"
     ],
     [
       "To that golden hair",
       "To that beautiful hair",
       "All of our hearts in",
       "To the steps in",
       "To those dazzling eyes"
     ], 1}
  end

  defp lyric_options(5) do
    {[
       "We gave",
       "To that beautiful hair",
       "And those dazzling eyes.",
       "To the steps in",
       "To those dazzling eyes"
     ],
     [
       "We gave",
       "To that beautiful hair",
       "And those dazzling eyes.",
       "To the steps in",
       "To those dazzling eyes"
     ], 3}
  end
end
