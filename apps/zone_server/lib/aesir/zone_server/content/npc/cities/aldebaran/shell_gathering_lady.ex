defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.ShellGatheringLady do
  @moduledoc """
  Explains shell gathering and warns travelers about Ambernites.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 81,
        y: 61,
        dir: 4,
        sprite: 101,
        name: "Shell Gathering Lady",
        scope: :shared,
        unique_name: "Shell Gathering Lady#ald"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Joanne]")
      |> mes("I enjoy gathering shells from the sea. It's really fun and relaxing~")
      |> next()
      |> select(["Shell Gathering?", "End Conversation"])

    if choice == 1 do
      ctx
      |> mes("[Joanne]")
      |> mes(
        "When you see bubbles popping up from the sand or muddy puddles, try digging into the ground a bit. You might find some shells underneath the ground!"
      )
      |> next()
      |> mes("[Joanne]")
      |> mes("Have you heard")
      |> mes("of Ambernite?")
      |> mes("That shell monster")
      |> mes("is pretty tough~")
      |> next()
      |> mes("[Joanne]")
      |> mes(
        "It's usually seen at the beach near the west province of Prontera. If you ever try attacking it without being prepared, you might be in trouble."
      )
      |> next()
      |> mes("[Joanne]")
      |> mes("Ambernite is")
      |> mes("pretty strong!")
      |> mes("So look out for it!")
      |> close()
    else
      ctx
      |> mes("[Joanne]")
      |> mes("Ambernite is")
      |> mes("pretty strong!")
      |> mes("So look out for it!")
      |> close()
    end
  end
end
