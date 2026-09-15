defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Soldier274239 do
  @moduledoc """
  Shares a Manuk resident's remarks according to whether the visitor understands the local language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "manuk",
        x: 274,
        y: 239,
        dir: 5,
        sprite: 455,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ep13_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Injured Manuk Soldier]")
      |> mes("I can't absorb Bradium Essence anymore because of my fatal injury.")
      |> mes("Those wicked fairies attacked me and left me like this.")
      |> close()
    else
      ctx
      |> mes("[Injured Manuk Soldier]")
      |> mes("Bhiio aaas dgwer fdds rrrrrpppp Ee")
      |> close()
    end
  end
end
