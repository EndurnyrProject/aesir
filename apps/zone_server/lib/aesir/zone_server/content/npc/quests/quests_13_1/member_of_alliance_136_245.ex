defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MemberOfAlliance136245 do
  @moduledoc """
  A Rune-Midgarts alliance member posted in Lighthalzen, one of the eight voices around
  the expedition.

  ## Behavior

  - Points the player past step 19 at the dimensional rift guard instead of talking.
  - Otherwise weighs the two alliance heads' differences against their friendship.

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
        x: 136,
        y: 245,
        dir: 1,
        sprite: 869,
        name: "Member of Alliance",
        scope: :shared,
        unique_name: "Member of Alliance#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @hint "-You should probably head over to the dimensional rift next to Morocc and find the Guard there-"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) > 19 do
      pointed_to_rift(ctx)
    else
      chatter(ctx)
    end
  end

  defp pointed_to_rift(ctx) do
    ctx
    |> mes(@hint)
    |> close()
  end

  defp chatter(ctx) do
    ctx
    |> mes("[Member of Alliance]")
    |> mes("The heads of the alliance, Sikaiz and Munkenro...")
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("They have different values,")
    |> mes("so that sometimes causes conflict, but nothing serious has happened so far.")
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("Friendship is the most valuable in this world.")
    |> close()
  end
end
