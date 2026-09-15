defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Galtun256143 do
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
        x: 256,
        y: 143,
        dir: 3,
        sprite: 450,
        name: "Galtun",
        scope: :shared,
        unique_name: "Galtun#ep13_2_3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Galtun]")
      |> mes("I will devote myself to")
      |> mes("protect my family and Saphas.")
      |> mes("That is all I want...")
      |> close()
    else
      ctx
      |> mes("[Galtun]")
      |> mes("Mr ishh qw e ee")
      |> mes("Baa eou sh ua sd")
      |> mes("Up idhs ish dk I jsd")
      |> close()
    end
  end
end
