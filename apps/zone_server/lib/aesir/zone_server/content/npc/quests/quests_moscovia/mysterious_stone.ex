defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.MysteriousStone do
  @moduledoc """
  A mysterious stone marks three dangerous paths.

  ## Behavior

  - The stone drains, curses, or summons the wolf depending on the chosen path.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_dun01",
        x: 169,
        y: 162,
        dir: 0,
        sprite: 111,
        name: "Mysterious Stone",
        scope: :shared,
        unique_name: "Mysterious Stone#rus02"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :rhea_rus_main, 0)

    cond do
      not Rathena.truthy?(stage) ->
        ctx |> mes("- The road forks here -") |> close()

      stage < 3 ->
        choose_path(ctx)

      stage == 3 or stage == 4 ->
        wait_for_wolf(ctx)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp choose_path(ctx) do
    ctx =
      ctx
      |> mes("- Words are engraved -")
      |> mes("- on the stone -")
      |> next()
      |> mes("- Right path -> Drain -")
      |> mes("- Left path -> Curse -")
      |> mes("- Middle -> ? -")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...Where should I go?")
      |> next()
      |> select(["Right", "Left", "Middle"])

    case choice do
      1 -> right_path(ctx)
      2 -> left_path(ctx)
      3 -> middle_path(ctx)
      _ -> ctx
    end
  end

  defp right_path(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...What about the right...")
      |> next()
      |> mes("- You decide to go to the right -")
      |> next()
      |> mes("- !!!!!! -")
      |> percent_heal(hp: -50, sp: -50)
      |> specialeffect2(:darkbreath)
      |> specialeffect2(:hit2)

    ctx
    |> emotion(:huk, playerattached(ctx))
    |> next()
    |> mes("- An unknown force has -")
    |> mes("- drained your health -")
    |> close2()
    |> warp("mosk_dun01", 190, 47)
  end

  defp left_path(ctx) do
    ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

    ctx =
      if not Rathena.truthy?(ismounting(ctx)) do
        ctx =
          ctx
          |> mes("...What about the left...?")
          |> next()
          |> mes("- You decide to go to the left -")
          |> next()
          |> mes("- !!!!!! -")

        ctx
        |> emotion(:huk, playerattached(ctx))
        |> next()
        |> mes("- An unknown force has -")
        |> mes("- cursed your body -")
      else
        ctx =
          ctx
          |> mes("...What about the left...?")
          |> next()
          |> mes("- You decide to go to the left -")
          |> next()
          |> mes("- !!!!!! -")

        ctx
        |> emotion(:huk, playerattached(ctx))
        |> next()
        |> mes("- Your trusty Pecopeco senses -")
        |> mes("- an unknown force and tries -")
        |> mes("- to run away!! -")
        |> set_riding(false)
      end

    ctx |> sc_start(:sc_curse, 60_000, 0) |> close2() |> warp("mosk_dun01", 190, 47)
  end

  defp middle_path(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...What about the middle...?")
      |> next()
      |> mes("- You move forward -")
      |> mes("- toward the middle -")
      |> next()
      |> mes("- !!!!!! -")

    ctx
    |> emotion(:huk, playerattached(ctx))
    |> donpcevent("Gray Wolf#rus03::OnEnable")
    |> set_char_var(:rhea_rus_main, 2)
    |> close()
  end

  defp wait_for_wolf(ctx) do
    ctx =
      ctx
      |> mes("- Words are engraved -")
      |> mes("- on the stone -")
      |> next()
      |> mes("- Right path -> Drain -")
      |> mes("- Left path -> Curse -")
      |> mes("- Middle -> ? -")
      |> next()
      |> mes("- You carefully read the stone -")
      |> mes("- and decide to wait -")

    ctx =
      if get_char_var(ctx, :rhea_rus_main, 0) == 3 do
        set_char_var(ctx, :rhea_rus_main, 4)
      else
        ctx
      end

    ctx |> donpcevent("Gray Wolf#rus03::OnEnable") |> close()
  end
end
