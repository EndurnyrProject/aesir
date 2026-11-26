defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Researcher5547 do
  @moduledoc """
  Kurdt, a researcher of the Sleipnir Seal quest who wants marine materials to recreate the
  'Spirit of Fish'.

  ## Behavior

  - Outside the Sleipnir seal phase, or before the player is assigned to the researchers, he
    only muses about passion in research.
  - A player just sent by the manager becomes his assistant; he then asks for a wide variety of
    marine materials, about ten of each.
  - On return he counts the materials the player holds at least nine of; with fifteen or more
    kinds he takes nine of each such material and the player's research stage advances,
    otherwise he asks for more variety.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god01",
        x: 55,
        y: 47,
        dir: 3,
        sprite: 803,
        name: "Researcher",
        scope: :shared,
        unique_name: "Researcher#G3"
      }
    ]

  @materials [
    918,
    950,
    951,
    956,
    959,
    960,
    961,
    962,
    963,
    964,
    965,
    966,
    1023,
    1024,
    1050,
    1051,
    1052,
    1053,
    1054,
    7013
  ]

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      ctx
      |> take_new_assistant()
      |> research_task()
    else
      muse(ctx)
    end
  end

  defp take_new_assistant(ctx) do
    if get_char_var(ctx, :god_sl_1, 0) == 2 do
      set_char_var(ctx, :god_sl_1, 31)
    else
      ctx
    end
  end

  defp research_task(ctx) do
    if get_char_var(ctx, :god_sl_1, 0) in [31, 42, 13, 24] do
      case get_char_var(ctx, :god_sl_2, 0) do
        0 -> request_materials(ctx)
        1 -> check_materials(ctx)
        _ -> ctx
      end
    else
      muse(ctx)
    end
  end

  defp request_materials(ctx) do
    ctx
    |> mes("[Kurdt]")
    |> mes("Ah, you must be")
    |> mes("the new assistant.")
    |> mes("Pleased to meet you.")
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "In all honesty, I was expecting someone with a bit more experience in the field of research, but it's understandable."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "After all, we're not in the position to expect professional assistance. In any case, I believe you'll bring a new perspective to our work."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "I've almost completed my project and don't need too much in the way of manpower. However, the last task I need finished is difficult."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "I was thinking of using my own funds to hire an outside agency, but there's no need to do that now that you're here~"
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "What I'd like to ask you to do is to gather materials so that I can create the 'Spirit of Fish.'"
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "I'm not sure if I can actually produce it or not, but we can at least give this experiment a try."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "Basically, you and collect things like 'Fish Scales' or Fish Tails,' basically anything you can obtain from marine life."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes("I don't need a")
    |> mes("ridiculous amount of one")
    |> mes(
      "kind of material, I'd say about 10 of one kind of each item should work. Give or take 5..."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "I should mention that I also require a good variety of marine related materials. You can't conduct an experiment without different objects to test, right?"
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "Anyway, I hope you don't run into too much trouble finding what I need for this experiment. Good luck~"
    )
    |> set_char_var(:god_sl_2, 1)
    |> close()
  end

  defp check_materials(ctx) do
    ctx =
      ctx
      |> mes("[Kurdt]")
      |> mes("Ah, you've returned.")
      |> mes("Okay, let me check")
      |> mes("what you brought to me. Hmm...")
      |> next()
      |> mes("[Kurdt]")
      |> mes("Ooh...")
      |> mes("I could use these.")
      |> mes("And these too. Oh!")
      |> mes("You adventurers carry")
      |> mes("a lot of things, don't you?")

    kinds = Enum.count(@materials, &(count_item(ctx, &1) > 8))
    ctx = next(ctx)

    if kinds > 14 do
      accept_materials(ctx)
    else
      ctx
      |> mes("[Kurdt]")
      |> mes("Still, you don't seem to have enough materials for me to")
      |> mes("complete my research")
      |> mes("Remember, I need")
      |> mes("a huge variety.")
      |> next()
      |> mes("[Kurdt]")
      |> mes(
        "I'm sorry for the hassle, but do you think you could go out and collect things so that I can attempt to recreate the"
      )
      |> mes("'Spirit of Fish?'")
      |> close()
    end
  end

  defp accept_materials(ctx) do
    ctx
    |> mes("[Kurdt]")
    |> mes("Ah....!")
    |> mes(
      "The materials you have should be enough for me to conduct my experiment. Thank you so much."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "With these, I can continue my research without any problem. I'm pleasantly surprised with the job you've done."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes("You really were")
    |> mes("such a great help.")
    |> mes("Thank you so much!")
    |> mes("Hahaha....!")
    |> next()
    |> mes("[Kurdt]")
    |> mes("Now, there may be")
    |> mes("other researchers")
    |> mes(
      "who might need your help in completing their projects. Why don't you ask around to see if"
    )
    |> mes("they need anything?")
    |> take_materials()
    |> set_char_var(:god_sl_2, 0)
    |> advance_stage()
    |> close()
  end

  defp take_materials(ctx) do
    Enum.reduce(@materials, ctx, fn item_id, ctx ->
      if count_item(ctx, item_id) > 8, do: delitem(ctx, item_id, 9), else: ctx
    end)
  end

  defp advance_stage(ctx) do
    case get_char_var(ctx, :god_sl_1, 0) do
      31 -> set_char_var(ctx, :god_sl_1, 32)
      42 -> set_char_var(ctx, :god_sl_1, 43)
      13 -> set_char_var(ctx, :god_sl_1, 14)
      24 -> set_char_var(ctx, :god_sl_1, 50)
      _ -> ctx
    end
  end

  defp muse(ctx) do
    ctx
    |> mes("[Kurdt]")
    |> mes("Hmmm....")
    |> mes("Funds and")
    |> mes("manpower are")
    |> mes("important for")
    |> mes("research to progress.")
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "But no amount of financing or staffing can replace the value of enthusiasm and passion in conducting research."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "Some financiers are so ignorant that they think that if they throw more money and people into a project, the secrets of science will be unlocked that much faster."
    )
    |> next()
    |> mes("[Kurdt]")
    |> mes(
      "But if the people doing your research are unmotivated and uninspired, you'll never get anywhere."
    )
    |> close()
  end
end
