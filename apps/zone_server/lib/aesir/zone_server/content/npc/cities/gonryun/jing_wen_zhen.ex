defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.JingWenZhen do
  @moduledoc """
  Laments the marriage prospects of Kunlun's many unmarried men.

  ## Credits

  - Original from rAthena, authors and Contributors
    - x[tsk]
    - KarLaeda

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gonryun",
        x: 181,
        y: 161,
        dir: 3,
        sprite: 773,
        name: "Jing Wen Zhen",
        scope: :shared,
        unique_name: "Jing Wen Zhen#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Jing Wen Zhen]")
    |> mes("The men in our town, Kunlun, are")
    |> mes("all brave and courageous.")
    |> mes("But, they are unable to get")
    |> mes("married. It's quite a shame really...")
    |> next()
    |> mes("[Jing Wen Zhen]")
    |> mes("It's all because there are")
    |> mes("more men than women.")
    |> mes("I am not even sure whether")
    |> mes("or not my son will be able to")
    |> mes("find me a daughter in law.")
    |> close()
  end
end
