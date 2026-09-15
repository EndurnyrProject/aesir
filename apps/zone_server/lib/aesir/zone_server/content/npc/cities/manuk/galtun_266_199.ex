defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Galtun266199 do
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
        x: 266,
        y: 199,
        dir: 5,
        sprite: 450,
        name: "Galtun",
        scope: :shared,
        unique_name: "Galtun#ep13_2_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Galtun]")
      |> mes("I can relax now that we have those piles of Bradium.")
      |> mes("But I am also worried that we can spend them in a short time.")
      |> close()
    else
      ctx
      |> mes("[Galtun]")
      |> mes("Bu iu bus sfi a sd")
      |> mes("Zsd dwo uf sh osad ")
      |> mes("Qdf aih fas io d hoas")
      |> mes("Nas d iy as di")
      |> close()
    end
  end
end
