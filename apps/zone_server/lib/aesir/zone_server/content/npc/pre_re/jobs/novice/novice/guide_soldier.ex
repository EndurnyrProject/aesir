defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.GuideSoldier do
  @moduledoc """
  Explains town guides and tutor locations to pre-renewal novices.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-2",
        x: 121,
        y: 101,
        dir: 2,
        sprite: 105,
        name: "Guide Soldier",
        unique_name: "Guide Soldier#nv1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Guide Soldier]")
    |> mes(
      "We Guide Soldiers provide location information at the entrance of every town. You can easily find us by our special uniforms."
    )
    |> next()
    |> mes("[Guide Soldier]")
    |> mes("Whenever you visit a town")
    |> mes(
      "for the first time, we would like to recommend that you check the locations of notable places in town with us."
    )
    |> next()
    |> mes("[Guide Soldier]")
    |> mes(
      "If you wish to take an Informative class, please walk around and speak to the various tutors in these Training Grounds. Have a good day."
    )
    |> close()
  end
end
