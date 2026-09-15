defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.ManukPiom103311 do
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
        x: 103,
        y: 311,
        dir: 3,
        sprite: 455,
        name: "Manuk Piom",
        scope: :shared,
        unique_name: "Manuk Piom#tre2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx |> mes("[Manuk Piom]") |> mes("My leg...") |> mes("It's time to already.") |> close()
    else
      ctx |> mes("[Manuk Piom]") |> mes("Fn is d id ") |> mes("Yon sdi dh so dps") |> close()
    end
  end
end
