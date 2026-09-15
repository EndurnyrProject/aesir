defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.Bonubonu283203 do
  @moduledoc """
  Shares Bonubonu's reflections on Amatsu's legendary cherry tree.

  ## Behavior

  - Marks the tree conversation as Bonubonu's perspective.
  - Describes the tree's fragrance and calming effect.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 283,
        y: 203,
        dir: 1,
        sprite: 111,
        name: "Bonubonu",
        scope: :shared,
        unique_name: "Bonubonu#ama2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> set_char_var(:jap_tree, 3)
    |> emotion(:profusely_sweat)
    |> mes("[Bonubonu]")
    |> mes("That tree on the hill is")
    |> mes("a very old tree. It is a big")
    |> mes("cherry tree with everlasting blossoms.")
    |> next()
    |> emotion(:profusely_sweat)
    |> mes("[Bonubonu]")
    |> mes("There is something about this")
    |> mes("tree that makes me forget about")
    |> mes("all the troubles in my life when I sit under it.")
    |> next()
    |> emotion(:profusely_sweat)
    |> mes("[Bonubonu]")
    |> mes("Everything about this tree is")
    |> mes("simply wonderful...")
    |> mes("I can't really describe how")
    |> mes("I feel when I look at it...")
    |> mes("It just leaves me breathless...")
    |> next()
    |> emotion(:profusely_sweat)
    |> mes("[Bonubonu]")
    |> mes("You should visit the tree and")
    |> mes("spend some time there.")
    |> mes("It is really a miraculous and gracious tree...")
    |> close()
  end
end
