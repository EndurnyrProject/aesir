defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MemberOfAlliance do
  @moduledoc """
  A Rune-Midgarts alliance member posted in Lighthalzen, one of the eight voices around
  the expedition.

  ## Behavior

  - Points the player past step 19 at the two bickering scholars instead of talking.
  - Agrees with the player through the rest of the expedition.

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
        x: 128,
        y: 249,
        dir: 1,
        sprite: 904,
        name: "Member of Alliance",
        scope: :shared,
        unique_name: "Member of Alliance#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) > 19 do
      arguing_kingdoms(ctx)
    else
      agreement(ctx)
    end
  end

  defp arguing_kingdoms(ctx) do
    ctx
    |> mes("-Munkenro and Sakaiz don't seem to be getting along very well anymore.-")
    |> close()
  end

  defp agreement(ctx) do
    ctx
    |> mes("[Member of Alliance]")
    |> mes("Hm, ok!")
    |> mes("That's right.")
    |> close()
  end
end
