defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Brisindwarf2 do
  @moduledoc """
  Hides Dvalin's entrance beneath a moss-covered rock.

  ## Behavior

  - Restricts the rock's interaction according to the seal and quest progress.
  - Offers a way down and a tile puzzle that reveals Dvalin.

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
        map: "prt_fild02",
        x: 185,
        y: 269,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#brisindwarf2",
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
        ordinary_rock(ctx)

      get_server_var(ctx, "God3", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        ordinary_rock(ctx)

      get_char_var(ctx, :god_brising, 0) > 41 ->
        inspect_rock(ctx)

      true ->
        ctx |> mes("^3355FFJust a normal") |> mes("rock, covered in moss.^000000") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :god_brising, 0) > 41 do
      emotion(ctx, :surprise, playerattached(ctx))
    else
      ctx
    end
  end

  defp ordinary_rock(ctx) do
    ctx |> mes("^3355FFIt's just an") |> mes("ordinary rock.^000000") |> close()
  end

  defp inspect_rock(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFIt's just an ordinary rock underneath the shadow of")
      |> mes(
        "a tree. But on closer inspection, you notice that the moss on top of the rock looks perfectly flat.^000000"
      )
      |> next()
      |> select(["Step on it.", "Sweep the surface.", "Scratch the surface.", "Kick it."])

    case choice do
      1 ->
        ctx
        |> mes(
          "^3355FFYou gingerly place your foot on the top of the stone. The entire rock suddenly swings downward"
        )
        |> mes("into the ground, and you fall helplessly...^000000")
        |> close2()
        |> warp("prt_fild02", 165, 224)

      2 ->
        ctx
        |> mes(
          "^3355FFAs you sweep away the moss with your hand, you scratch your palm from the sharp edges of the rock.^000000"
        )
        |> emotion(:surprise, playerattached(ctx))
        |> next()
        |> mes(player_name(ctx))
        |> mes("Damn...!")
        |> mes("I'm bleeding!")
        |> mes("But why didn't")
        |> mes("anything else")
        |> mes("happen?!")
        |> next()
        |> mes(player_name(ctx))
        |> mes("This rock had")
        |> mes("better be one of")
        |> mes("those secret rocks!")
        |> mes("Or else...!")
        |> close()

      3 ->
        solve_puzzle(ctx)

      4 ->
        ctx
        |> mes(player_name(ctx))
        |> mes("^333333*Cough cough!*")
        |> mes("Aaaack!")
        |> mes("It's so dusty!")
        |> close()

      _ ->
        ctx
    end
  end

  defp solve_puzzle(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou scratch away")
      |> mes("at the moss, and feel that the surface of the rock has even recesses.")
      |> next()
      |> mes(
        "^3355FFAfter peeling off the moss, a series of tiles, etched with faint words, are revealed on top of the rock. These tiles could be moved around, like in a puzzle.^000000"
      )
      |> next()
      |> mes(player_name(ctx))
      |> mes("Another puzzle?")
      |> mes("This was just like when I had to give Alfrik's password. Okay, let me see...")
      |> set_local(:point, 0)
      |> next()

    puzzle_first(ctx)
  end

  defp puzzle_first(ctx) do
    options = [
      "To the tear drops dripping on the way",
      "Her lovely scent",
      "We gave",
      "To the seducing red lips",
      "Our hearts in"
    ]

    {ctx, choice} = select(ctx, options)

    if choice in 1..5 do
      ctx = ctx |> mes(player_name(ctx)) |> mes(Enum.at(options, choice - 1))
      ctx = if choice == 2, do: add_point(ctx), else: ctx
      puzzle_second(ctx)
    else
      ctx
    end
  end

  defp puzzle_second(ctx) do
    options = [
      "Still lingers in the wind.",
      "To the scent drifted in the wind",
      "We gave",
      "To the seducing red lips",
      "Our hearts in"
    ]

    {ctx, choice} = select(ctx, options)

    if choice in 1..5 do
      ctx = mes(ctx, Enum.at(options, choice - 1))
      ctx = if choice == 1, do: add_point(ctx), else: ctx
      ctx = if choice == 4, do: mes(ctx, "Our hearts in"), else: ctx
      puzzle_third(ctx)
    else
      ctx
    end
  end

  defp puzzle_third(ctx) do
    options = [
      "To the tear drops dripping on the way",
      "To the scent drifted in the wind",
      "We gave",
      "We surrendered our hearts",
      "Our hearts in"
    ]

    {ctx, choice} = select(ctx, options)

    if choice in 1..5 do
      ctx = mes(ctx, Enum.at(options, choice - 1))
      ctx = if choice == 4, do: add_point(ctx) |> mes("Our hearts in"), else: ctx
      puzzle_fourth(ctx)
    else
      ctx
    end
  end

  defp puzzle_fourth(ctx) do
    options = [
      "To the tear drops dripping on the way",
      "To the scent drifted in the wind",
      "To those tender teardrops",
      "To the seducing red lips",
      "Our hearts in"
    ]

    {ctx, choice} = select(ctx, options)

    if choice in 1..5 do
      ctx = mes(ctx, Enum.at(options, choice - 1))
      ctx = if choice == 3, do: add_point(ctx), else: ctx
      puzzle_fifth(ctx)
    else
      ctx
    end
  end

  defp puzzle_fifth(ctx) do
    options = [
      "To the tear drops dripping on the way",
      "To the scent drifted in the wind",
      "We gave",
      "To the seducing red lips",
      "Those seductive red lips"
    ]

    {ctx, choice} = select(ctx, options)

    if choice in 1..5 do
      ctx = mes(ctx, Enum.at(options, choice - 1))
      ctx = if choice == 5, do: add_point(ctx), else: ctx
      ctx = next(ctx)

      if get_local(ctx, :point, 0) > 40 do
        ctx
        |> hideoffnpc("Dvalin#1")
        |> mes("[Dvalin]")
        |> mes("...?")
        |> mes("Alfrik?")
        |> mes("Is that you?")
        |> close()
      else
        close(ctx)
      end
    else
      ctx
    end
  end

  defp add_point(ctx), do: set_local(ctx, :point, get_local(ctx, :point, 0) + 10)

  defp player_name(ctx), do: "[#{char_name(ctx, 0)}]"
end
