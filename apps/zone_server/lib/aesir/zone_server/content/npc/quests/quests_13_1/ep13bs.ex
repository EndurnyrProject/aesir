defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Ep13bs do
  @moduledoc """
  The hidden bed in the expedition camp's main building that ends the first night of the
  Ash-Vacuum quest.

  ## Behavior

  - Before step 4 and between steps 4 and 9 the bed is made and unused.
  - On step 10 the player sleeps through the night, sets `ep13_newbs` to 11 and is sent to
    Instructor Lugen.
  - On any later step the bed is described as the one the player uses.

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
        map: "mid_campin",
        x: 291,
        y: 128,
        dir: 1,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#ep13bs",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: sleep_in(ctx)

  defp sleep_in(ctx) do
    case get_char_var(ctx, :ep13_newbs, 0) do
      step when step < 4 -> unused_bed(ctx)
      step when step < 10 -> claimed_bed(ctx)
      10 -> good_night(ctx)
      _step -> comfortable_bed(ctx)
    end
  end

  defp unused_bed(ctx) do
    ctx
    |> mes("- It's a neat and tidy bed -")
    |> mes("- It seems that nobody used it. -")
    |> close()
  end

  defp claimed_bed(ctx) do
    ctx
    |> mes("- It's a neat and tidy bed -")
    |> mes("- It seems that I will use this one. -")
    |> close()
  end

  defp good_night(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Haaaam~~~~~")
    |> mes("what a good night!!")
    |> next()
    |> mes("- I slept well -")
    |> mes("- and feel better. -")
    |> mes("- I think I need to go -")
    |> mes("- to Instructor Lugen -")
    |> set_char_var(:ep13_newbs, 11)
    |> close()
  end

  defp comfortable_bed(ctx) do
    ctx
    |> mes("- The bed that I use -")
    |> mes("- It is comfortable. -.")
    |> close()
  end
end
