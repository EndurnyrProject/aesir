defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.HeapOfEarth do
  @moduledoc """
  The heap of earth in the Huwaei field where Rin's fight against Rayan's gang left its
  traces.

  ## Behavior

  - Refuses a player who cannot pick up an item.
  - On `mao_morocc2` step 7 plays the battle site survey and offers a two-option menu: ignoring
    the aura ends the dialog, looking closely yields the Bloody Crystal of Darkness, sets the
    step to 8 and advances quest 7016 to 7017.
  - On step 8 and on every other step only describes the traces.
  - Plays the ground effect on touch while on step 7.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_fild04",
        x: 235,
        y: 103,
        dir: 0,
        sprite: 844,
        name: "Heap of Earth",
        scope: :shared,
        unique_name: "Heap of Earth#mao2_01",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @bloody_crystal 6027
  @investigation_step 7

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: reveal_traces(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{714, 1}]) == 0 do
      overburdened(ctx)
    else
      investigate(ctx)
    end
  end

  defp overburdened(ctx) do
    ctx
    |> mes("- You cannot proceed with the quest when you're carrying too many items with you. -")
    |> close()
  end

  defp investigate(ctx) do
    case get_char_var(ctx, :mao_morocc2, 0) do
      @investigation_step -> site_survey(ctx)
      8 -> traces_of_battle(ctx)
      _step -> traces(ctx)
    end
  end

  defp site_survey(ctx) do
    ctx =
      ctx
      |> specialeffect(:level99_4)
      |> mes("You have found a pile of dirt and deep tracks under thick bushes.")
      |> mes("There are deep footprints and spilled blood around the area.")
      |> next()
      |> mes("Some desperate fighting definitely happened here.")
      |> mes(
        "There are some broken branches to the side of a set of footprints that look like they're skidding backwards..."
      )
      |> mes("Somebody must have been fallen down on the ground, or...")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I've been having a strange feeling around this area...")
      |> mes("It feels like faint mana.. ?!... Yes, I can barely see an aura.")
      |> mes("...What is this?")
      |> next()
      |> select(["Ignore it.", "Take a careful look."])

    case choice do
      1 -> ignore_aura(ctx)
      2 -> take_look(ctx)
      _ -> ctx
    end
  end

  defp ignore_aura(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Hmm.. This place must be where Rin fought with Rayan's gang.")
    |> mes("I don't see anything that looks important.")
    |> close()
  end

  defp take_look(ctx) do
    ctx =
      ctx
      |> mes("As you took a careful look,")
      |> mes("you notice something shining in the ground.")
      |> next()
      |> mes("^4d4dffYou have found a 'Bloody Crystal of Darkness'.^000000")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I don't think I'll find anything else here...")
    |> mes("I should go back now.")
    |> mes("I hope Rin will understand.")
    |> set_char_var(:mao_morocc2, 8)
    |> give_item(@bloody_crystal, 1)
    |> changequest(7016, 7017)
    |> close()
  end

  defp traces_of_battle(ctx) do
    ctx
    |> mes("There are traces of a battle here, including spilled blood.")
    |> mes("There's also a pile of dirt that seems out of place.")
    |> close()
  end

  defp traces(ctx) do
    ctx
    |> mes("There are traces of a battle here, and spilled blood.")
    |> close()
  end

  defp reveal_traces(ctx) do
    if get_char_var(ctx, :mao_morocc2, 0) == @investigation_step do
      specialeffect(ctx, :level99_4)
    else
      ctx
    end
  end
end
