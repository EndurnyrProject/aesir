defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Piom245124 do
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
        x: 245,
        y: 124,
        dir: 3,
        sprite: 455,
        name: "Piom",
        scope: :shared,
        unique_name: "Piom#ep13_2_4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Piom]")
      |> mes("Human, you think our battle is stupid, don't you?")
      |> mes("And a waste of time?")
      |> mes("But it is really depends on this war whether we can survive or not.")
      |> close()
    else
      ctx
      |> mes("[Piom]")
      |> mes("Nsa dhi pao sdi a jp das")
      |> mes("Uaa as iijds kn sdg f")
      |> mes("Bzi hd sia pasd ")
      |> mes("Es do ja pda sj d")
      |> mes("Bs oju lujdi ni sdgf g ")
      |> next()
      |> mes("[Piom]")
      |> mes("Us id jd nai dh")
      |> close()
    end
  end
end
