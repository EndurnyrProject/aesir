defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Piom286147 do
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
        x: 286,
        y: 147,
        dir: 3,
        sprite: 454,
        name: "Piom",
        scope: :shared,
        unique_name: "Piom#ep13_2_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Piom]")
      |> mes("I'll never forget the deep-rooted rancor against those traitors.")
      |> mes("I remember how our ancestors died.")
      |> mes("I swear that I would avenge them.")
      |> next()
      |> mes("[Piom]")
      |> mes("First, I'll kick those bastards.")
      |> mes("Those flying little things bother me so much.")
      |> close()
    else
      ctx
      |> mes("[Piom]")
      |> mes("Vio hs pf I aps")
      |> mes("Vs ou oas de ee")
      |> mes("Bzi sh da opd")
      |> mes("Mc oju asop dj a ps")
      |> next()
      |> mes("[Piom]")
      |> mes("Be juas da sd")
      |> mes("Eoj ssr owq w e ")
      |> mes("Wps dj i ao sj daasd asd")
      |> close()
    end
  end
end
