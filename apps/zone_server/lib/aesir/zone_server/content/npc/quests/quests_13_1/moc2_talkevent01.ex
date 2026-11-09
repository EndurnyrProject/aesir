defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Moc2Talkevent01 do
  @moduledoc """
  Speech trigger that wakes a questing player up as Mr. Kidd at the Morocc camp.

  ## Behavior

  - Fires on touch and on talk only while the player's `mao_morocc2` step is 11.
  - Plays Mr. Kidd's wake-up call and advances `mao_morocc2` to 12.

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
        map: "mid_camp",
        x: 205,
        y: 312,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#moc2_talkevent01",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: wake_up(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: wake_up(ctx)

  defp wake_up(ctx) do
    if get_char_var(ctx, :mao_morocc2, 0) == 11 do
      name = char_name(ctx, 0)

      ctx
      |> mes("[Mr. Kidd]")
      |> mes("#{name}? #{name}?!")
      |> mes("Wake up!")
      |> set_char_var(:mao_morocc2, 12)
      |> close()
    else
      ctx
    end
  end
end
