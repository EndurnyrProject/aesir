defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MemberOfAlliance126249 do
  @moduledoc """
  A Rune-Midgarts alliance member posted in Lighthalzen, one of the eight voices around
  the expedition.

  ## Behavior

  - Points the player past step 19 at the dimensional rift guard instead of talking.
  - Otherwise wonders whether the three kingdoms can keep the peace.

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
        map: "lhz_in01",
        x: 126,
        y: 249,
        dir: 1,
        sprite: 930,
        name: "Member of Alliance",
        scope: :shared,
        unique_name: "Member of Alliance#7"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) > 19 do
      bickering(ctx)
    else
      three_kingdoms(ctx)
    end
  end

  defp bickering(ctx) do
    ctx
    |> mes(
      "-We haven't even started and we're already bickering. Just ignore the politics and head to the dimensional rift next to Morocc and find the Guard there-"
    )
    |> close()
  end

  defp three_kingdoms(ctx) do
    ctx
    |> mes("[Member of Alliance]")
    |> mes("Three kingdoms for world peace...")
    |> mes("Will it be successful?")
    |> close()
  end
end
