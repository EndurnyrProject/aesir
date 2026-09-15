defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Scientist do
  @moduledoc """
  Responds to visitors inside the restricted Regenschirm laboratory.

  ## Behavior

  - Discusses a confusing laboratory procedure with disguised staff.
  - Calls for guards and warps undisguised visitors out.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 203,
        y: 123,
        dir: 3,
        sprite: 750,
        name: "Scientist",
        scope: :shared,
        unique_name: "Scientist#li_02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.truthy?(is_equipped(ctx, 2241)) and Rathena.truthy?(is_equipped(ctx, 2243)) do
      ctx
      |> mes("[Scientist]")
      |> mes("Alright. Pull one test")
      |> mes("tube out of the machine,")
      |> mes("replace the other test")
      |> mes("tube over here and then")
      |> mes("clean the first test tube?")
      |> next()
      |> mes("[Scientist]")
      |> mes("Or do I clean the test tube,")
      |> mes("put it into the machine and")
      |> mes("then replace the other one?")
      |> mes("I'm so confused with this")
      |> mes("procedure! If only I didn't")
      |> mes("lose the instructions...")
      |> close()
    else
      ctx
      |> mes("[Scientist]")
      |> mes("Alright. Pull one test")
      |> mes("tube out of the machine,")
      |> mes("replace th--hey. You're")
      |> mes("not Ralphie. Wait. Guaaards!")
      |> mes("Help me, there's some weirdo!")
      |> emotion(:surprise)
      |> close()
      |> warp("lhz_in01", 33, 224)
    end
  end
end
