defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.OldWoodenBox do
  @moduledoc """
  A wooden box hiding part of a broken key.

  ## Behavior

  - Searching may reveal the handle of a broken key.

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
        map: "treasure01",
        x: 61,
        y: 183,
        dir: 0,
        sprite: 111,
        name: "Old_Wooden_Box",
        scope: :shared,
        unique_name: "Old_Wooden_Box#rus40"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_main, 0) == 23 ->
        {ctx, _} =
          ctx
          |> mes("- Something is glimmering inside of the box -")
          |> next()
          |> select(["Put hand inside the box"])

        if Enum.random(1..7) == 4 do
          ctx
          |> mes("- You take out something glimmering from the box -")
          |> next()
          |> mes("- ^0000ffYou find the handle of a broken key !!^000000 -")
          |> set_char_var(:rhea_rus_main, 24)
          |> close()
        else
          ctx
          |> mes("- You try to put your hand inside it but the gap is too small to do it -")
          |> next()
          |> mes("- You ruin the box a little -")
          |> close()
        end

      get_char_var(ctx, :rhea_rus_main, 0) > 23 and
          get_char_var(ctx, :rhea_rus_main, 0) < 26 ->
        ctx |> mes("- The old box that contained the handle of a broken key -") |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
